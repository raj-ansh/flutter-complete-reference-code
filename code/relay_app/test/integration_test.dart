// These tests use the REAL Relay server (book/code/relay_server, started as a
// child process) with this app's real socket and HTTP code. Only the screens
// are left out; the view models are driven directly.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:relay_app/core/result.dart';
import 'package:relay_app/data/models.dart';
import 'package:relay_app/data/session_store.dart';
import 'package:relay_app/data/transport.dart';
import 'package:relay_app/state/lobby_view_model.dart';
import 'package:relay_app/state/room_view_model.dart';
import 'package:relay_app/state/session_view_model.dart';

import 'support/capture.dart';

class RealServer {
  RealServer._(this._process, this.port);
  final Process _process;
  final int port;

  String get url => 'http://127.0.0.1:$port';

  static Future<RealServer> start({int port = 0, String? dataFile}) async {
    final process = await Process.start(
      'node',
      ['src/main.js', '$port'],
      workingDirectory: '../relay_server',
      environment: {'DATA_FILE': ?dataFile},
    );
    final lines = process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final first = await lines.firstWhere((l) => l.startsWith('PORT=')).timeout(const Duration(seconds: 15));
    process.stderr.drain<void>();
    return RealServer._(process, int.parse(first.substring(5)));
  }

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
  }
}

/// A session store that lives in memory, one per simulated phone.
class MemoryStore extends SessionStore {
  SavedSession? saved;
  @override
  Future<SavedSession?> read() async => saved;
  @override
  Future<void> save(String serverUrl, Session session) async =>
      saved = SavedSession(serverUrl: serverUrl, session: session);
  @override
  Future<void> clear() async => saved = null;
  @override
  Future<String?> lastServerUrl() async => saved?.serverUrl;
}

/// One simulated phone: its own transport, session and lobby.
class Phone {
  Phone(this.name) : transport = SocketIoTransport(reconnectDelayMs: 300) {
    session = SessionViewModel(store: store, client: http.Client(), transport: transport);
  }

  final String name;
  final SocketIoTransport transport;
  final store = MemoryStore();
  late final SessionViewModel session;
  LobbyViewModel? lobby;

  Future<Result<void>> signUp(String url, {bool create = true, String password = 'a long enough password'}) =>
      session.signIn(serverUrl: url, username: name, password: password, createAccount: create);

  Future<LobbyViewModel> openLobby() async {
    final l = LobbyViewModel(session.service, transport.events);
    lobby = l;
    await l.load();
    return l;
  }

  Future<RoomViewModel> openRoom(RoomSummary room) async {
    final me = (session.state as SignedIn).user.id;
    final vm = RoomViewModel(room: room, currentUserId: me, service: session.service, events: transport.events);
    await vm.load();
    return vm;
  }

  void dispose() {
    lobby?.dispose();
    session.dispose();
  }
}

Future<void> eventually(bool Function() condition, {String? what, int seconds = 10}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for ${what ?? 'a condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  setUpAll(() => HttpOverrides.global = null); // real sockets to localhost

  late RealServer server;
  final phones = <Phone>[];

  Phone phone(String name) {
    final p = Phone(name);
    phones.add(p);
    return p;
  }

  setUp(() async => server = await RealServer.start());
  tearDown(() async {
    for (final p in phones) {
      p.dispose();
    }
    phones.clear();
    await server.stop();
  });

  test('the real server refuses what it should, in words the app can show', () async {
    final alice = phone('alice');
    expect(await alice.signUp(server.url), isA<Ok<void>>());
    final rows = StringBuffer();

    Future<void> record(String label, Future<Result<void>> r) async {
      final result = await r;
      rows.writeln('${label.padRight(34)}${switch (result) {
        Ok() => 'ok',
        Err(:final code, :final message) => '$code: $message',
      }}');
    }

    await record('sign up with a taken name', phone('alice').signUp(server.url));
    await record('sign up with a short password', phone('bobby').signUp(server.url, password: 'short'));
    await record('sign in, wrong password', phone('alice').signUp(server.url, create: false, password: 'not the password'));
    await record('sign in, no such user', phone('nobody').signUp(server.url, create: false));
    await record('server not running (port 1)', phone('carol').signUp('http://127.0.0.1:1'));
    writeCaptured('relay_ch25_real_failures.txt', rows.toString());

    expect(rows.toString(), contains('conflict: That username is taken.'));
    expect(rows.toString(), contains('invalid: password must be at least 10 characters'));
    expect(rows.toString(), contains('unauthorized: Wrong username or password.'));
    expect(rows.toString(), contains('network: Could not reach the server.'));
  });

  test('two people chat through the real server', () async {
    final alice = phone('alice');
    final bob = phone('bob');
    await alice.signUp(server.url);
    await bob.signUp(server.url);
    await eventually(() => alice.session.online && bob.session.online, what: 'both connected');

    final aliceLobby = await alice.openLobby();
    final created = await aliceLobby.createRoom('Garden club', isPublic: true);
    final room = (created as Ok<RoomSummary>).value;

    final bobLobby = await bob.openLobby();
    expect((bobLobby.state as LobbyLoaded).others.map((r) => r.name), ['Garden club']);
    await bobLobby.join(bobLobby.byId(room.id)!);
    expect((bobLobby.state as LobbyLoaded).mine.map((r) => r.name), ['Garden club']);

    final aliceRoom = await alice.openRoom(room);
    final bobRoom = await bob.openRoom(bobLobby.byId(room.id)!);

    expect(await aliceRoom.send('  Is the basil watered?  '), isA<Ok<void>>());
    await eventually(() => (bobRoom.state as RoomActive).messages.isNotEmpty, what: "bob's copy of the message");
    expect(await bobRoom.send('Yes, this morning.'), isA<Ok<void>>());
    await eventually(() => (aliceRoom.state as RoomActive).messages.length == 2, what: "alice's copy of the reply");

    final log = StringBuffer('what each person sees in the room:\n');
    for (final (who, vm) in [('alice', aliceRoom), ('bob', bobRoom)]) {
      final messages = (vm.state as RoomActive).messages;
      log.writeln('  $who: ${messages.map((m) => '#${m.seq} ${m.username}: "${m.text}"').join('   ')}');
      expect(messages.map((m) => m.seq), [1, 2], reason: '$who sees each message exactly once');
      expect(messages.first.text, 'Is the basil watered?', reason: 'trimmed by the server');
    }
    writeCaptured('relay_ch25_real_chat.txt', log.toString());

    final members = (bobRoom.state as RoomActive).members;
    expect(members.map((m) => [m.username, m.isOwner, m.online]), [['alice', true, true], ['bob', false, true]]);
  });

  test('a saved token the server rejects signs the user out with a notice', () async {
    final alice = phone('alice');
    alice.store.saved = SavedSession(
      serverUrl: server.url,
      session: const Session(user: User(id: 'x', username: 'alice'), token: 'a-token-the-server-never-issued'),
    );
    await alice.session.restore();
    expect(alice.session.state, isA<SignedIn>(), reason: 'optimistic until the server says otherwise');
    await eventually(() => alice.session.state is SignedOut, what: 'sign-out after the refusal');
    expect((alice.session.state as SignedOut).notice, contains('Please sign in again'));
    expect(alice.store.saved, isNull);
  });

  test('an invitation and a removal reach the right phone', () async {
    final alice = phone('alice');
    final bob = phone('bob');
    await alice.signUp(server.url);
    await bob.signUp(server.url);
    await eventually(() => alice.session.online && bob.session.online);

    final aliceLobby = await alice.openLobby();
    final bobLobby = await bob.openLobby();
    final room = ((await aliceLobby.createRoom('Plans', isPublic: false)) as Ok<RoomSummary>).value;
    expect((bobLobby.state as LobbyLoaded).rooms, isEmpty, reason: 'a private room is invisible');

    final aliceRoom = await alice.openRoom(room);
    expect(await aliceRoom.invite('bob'), isA<Ok<void>>());
    await eventually(() => bobLobby.latestInvite != null, what: 'the invitation event');
    expect(bobLobby.latestInvite!.from, 'alice');
    // The event arrives first; the refreshed list follows a moment later.
    await eventually(() => (bobLobby.state as LobbyLoaded).invitations.isNotEmpty, what: "the lobby refresh");
    expect((bobLobby.state as LobbyLoaded).invitations.map((r) => r.name), ['Plans']);

    await bobLobby.join(bobLobby.byId(room.id)!);
    final bobRoom = await bob.openRoom(bobLobby.byId(room.id)!);
    expect(bobRoom.isOwner, isFalse);

    final refused = await bobRoom.kick('alice');
    expect((refused as Err).code, 'forbidden');

    expect(await aliceRoom.kick('bob'), isA<Ok<void>>());
    await eventually(() => bobRoom.state is RoomEnded, what: 'bob being removed');
    expect((bobRoom.state as RoomEnded).reason, contains('removed'));
    await eventually(() => (bobLobby.state as LobbyLoaded).mine.isEmpty, what: "bob's lobby refreshing");
  });

  test('the connection survives a server restart and chatting resumes', () async {
    final dir = Directory.systemTemp.createTempSync('relay_app_it_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // best effort
      }
    });
    await server.stop();
    final dataFile = '${dir.path}/data.json';
    server = await RealServer.start(dataFile: dataFile);
    final port = server.port;

    final alice = phone('alice');
    final bob = phone('bob');
    await alice.signUp(server.url);
    await bob.signUp(server.url);
    await eventually(() => alice.session.online && bob.session.online);
    final aliceLobby = await alice.openLobby();
    final room = ((await aliceLobby.createRoom('Durable', isPublic: true)) as Ok<RoomSummary>).value;
    final bobLobby = await bob.openLobby();
    await bobLobby.join(bobLobby.byId(room.id)!);
    final aliceRoom = await alice.openRoom(room);
    final bobRoom = await bob.openRoom(bobLobby.byId(room.id)!);
    await aliceRoom.send('before the restart');
    await eventually(() => (bobRoom.state as RoomActive).messages.length == 1);

    final timeline = StringBuffer();
    timeline.writeln('server stopped');
    await Future<void>.delayed(const Duration(milliseconds: 600)); // let the data file be written
    await server.stop();
    await eventually(() => !alice.session.online && !bob.session.online, what: 'both noticing the outage');
    timeline.writeln('  alice.online = ${alice.session.online}, bob.online = ${bob.session.online}');
    final offlineSend = await aliceRoom.send('typed while the server is down');
    timeline.writeln('  sending now: ${switch (offlineSend) {
      Err(:final code) => 'refused ($code)',
      Ok() => 'accepted?!',
    }}');
    expect(offlineSend, isA<Err<void>>());
    expect(alice.session.state, isA<SignedIn>(), reason: 'an outage does not sign anyone out');

    server = await RealServer.start(port: port, dataFile: dataFile);
    timeline.writeln('server started again on the same port, same data file');
    await eventually(() => alice.session.online && bob.session.online, what: 'both reconnecting', seconds: 20);
    timeline.writeln('  alice.online = ${alice.session.online}, bob.online = ${bob.session.online}');

    expect(await aliceRoom.send('after the restart'), isA<Ok<void>>());
    await eventually(() => (bobRoom.state as RoomActive).messages.length == 2, what: 'the new message at bob');
    timeline.writeln('  alice sends, bob receives: "${(bobRoom.state as RoomActive).messages.last.text}"');
    writeCaptured('relay_ch25_restart.txt', timeline.toString());
    expect((bobRoom.state as RoomActive).messages.map((m) => m.seq), [1, 2]);
  });
}
