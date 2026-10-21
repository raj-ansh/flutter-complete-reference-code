import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay_app/core/result.dart';
import 'package:relay_app/data/models.dart';
import 'package:relay_app/data/relay_service.dart';
import 'package:relay_app/data/transport.dart';
import 'package:relay_app/state/lobby_view_model.dart';
import 'package:relay_app/state/room_view_model.dart';
import 'package:relay_app/state/session_view_model.dart';

import 'support/capture.dart';
import 'support/fakes.dart';

/// Lets queued stream events and futures run.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  group('SessionViewModel', () {
    late FakeTransport transport;
    late List<String> httpLog;

    SessionViewModel make({Map<String, String> saved = const {}}) {
      final store = memoryStore(saved);
      final vm = SessionViewModel(
        store: store,
        client: authClient(log: httpLog),
        transport: transport,
      );
      addTearDown(vm.dispose);
      return vm;
    }

    setUp(() {
      transport = FakeTransport();
      httpLog = [];
    });

    test('with nothing saved, start-up ends signed out', () async {
      final vm = make();
      expect(vm.state, isA<Restoring>());
      await vm.restore();
      expect(vm.state, isA<SignedOut>());
      expect(transport.connectCalls, 0);
    });

    test('with a saved session, start-up is signed in at once and connects', () async {
      final vm = make(saved: savedSession());
      await vm.restore();
      expect((vm.state as SignedIn).user.username, 'alice');
      expect(transport.lastToken, 'token-alice');
      expect(transport.lastBase.toString(), 'http://10.0.2.2:3000');
      expect(vm.online, isFalse); // connecting; the banner says so
      transport.emit(const Connected());
      await settle();
      expect(vm.online, isTrue);
      transport.emit(const Disconnected('transport close'));
      await settle();
      expect(vm.online, isFalse);
      expect(vm.state, isA<SignedIn>(), reason: 'losing the network does not sign you out');
    });

    test('a saved session the server refuses ends signed out, with a notice', () async {
      final vm = make(saved: savedSession());
      await vm.restore();
      transport.emit(const ConnectFailed(unauthorized: true, detail: 'unauthorized'));
      await settle();
      final state = vm.state as SignedOut;
      expect(state.notice, contains('ended'));
      expect(await memoryStoreRead(vm), isNull); // the dead token was forgotten
      expect(transport.disconnectCalls, greaterThan(0));
    });

    test('an unreachable server is NOT a reason to sign out', () async {
      final vm = make(saved: savedSession());
      await vm.restore();
      transport.emit(const ConnectFailed(unauthorized: false, detail: 'ECONNREFUSED'));
      await settle();
      expect(vm.state, isA<SignedIn>());
    });

    test('signing in saves the session and opens the connection', () async {
      final vm = make();
      await vm.restore();
      final result = await vm.signIn(
        serverUrl: '10.0.2.2:3000',
        username: 'Alice',
        password: 'a long enough password',
        createAccount: false,
      );
      expect(result, isA<Ok<void>>());
      expect(vm.state, isA<SignedIn>());
      expect(transport.lastToken, 'token-alice');
      expect(httpLog, ['POST /api/login']);
      final saved = await memoryStoreRead(vm);
      expect(saved!.serverUrl, 'http://10.0.2.2:3000');
      expect(saved.session.token, 'token-alice');
    });

    test('every way sign-in can be refused leaves the user signed out', () async {
      final vm = make();
      await vm.restore();
      final rows = StringBuffer();
      Future<void> attempt(String label, String url, String user, String pw, {bool create = false}) async {
        final r = await vm.signIn(serverUrl: url, username: user, password: pw, createAccount: create);
        rows.writeln('${label.padRight(30)}${switch (r) {
          Ok() => 'ok',
          Err(:final code, :final message) => '$code: $message',
        }}');
        expect(r, isA<Err<void>>(), reason: label);
        expect(vm.state, isA<SignedOut>(), reason: label);
      }

      await attempt('wrong password', 'http://s:1', 'alice', 'wrong');
      await attempt('unknown user', 'http://s:1', 'nobody', 'a long enough password');
      await attempt('bad address', 'ftp://s', 'alice', 'a long enough password');
      await attempt('empty address', '', 'alice', 'a long enough password');
      expect(transport.connectCalls, 0);
      expect(httpLog.length, 2, reason: 'bad addresses never reach the network');
      writeCaptured('relay_ch25_signin_failures.txt', rows.toString());
    });

    test('signing out forgets the token, closes the socket and tells the server', () async {
      final vm = make(saved: savedSession());
      await vm.restore();
      await vm.signOut();
      expect(vm.state, isA<SignedOut>());
      expect(vm.online, isFalse);
      expect(await memoryStoreRead(vm), isNull);
      expect(transport.disconnectCalls, greaterThan(0));
      await settle();
      expect(httpLog, ['POST /api/logout']);
    });

    test('the server ending the session while connected signs the user out', () async {
      final vm = make(saved: savedSession());
      await vm.restore();
      transport.emit(const Connected());
      transport.emit(const SessionExpired());
      await settle();
      expect((vm.state as SignedOut).notice, contains('expired'));
    });
  });

  group('LobbyViewModel', () {
    late FakeTransport transport;
    late LobbyViewModel vm;
    var rooms = <Map<String, Object?>>[];

    setUp(() {
      rooms = [
        roomJson('r1', 'Garden'),
        roomJson('r2', 'Plans', isPublic: false, ownerId: 'u-bob', joined: false, invited: true),
        roomJson('r3', 'Lounge', ownerId: 'u-bob', joined: false),
      ];
      transport = FakeTransport(
        onRequest: (event, payload) =>
            event == 'rooms:list' ? Ok({'ok': true, 'rooms': rooms}) : null,
      );
      vm = LobbyViewModel(RelayService(transport), transport.events);
      addTearDown(vm.dispose);
    });

    test('rooms are grouped into mine, invitations and others', () async {
      await vm.load();
      final state = vm.state as LobbyLoaded;
      expect(state.mine.map((r) => r.name), ['Garden']);
      expect(state.invitations.map((r) => r.name), ['Plans']);
      expect(state.others.map((r) => r.name), ['Lounge']);
      expect(vm.byId('r2')!.name, 'Plans');
      expect(vm.byId('nope'), isNull);
    });

    test('a failed first load is an error; a failed later load keeps the list', () async {
      transport.onRequest = (_, _) => const Err('network', 'Not connected to the server.');
      await vm.load();
      expect(vm.state, isA<LobbyFailed>());
      transport.onRequest = (event, _) => Ok({'ok': true, 'rooms': rooms});
      await vm.load();
      expect(vm.state, isA<LobbyLoaded>());
      transport.onRequest = (_, _) => const Err('network', 'Not connected to the server.');
      await vm.load();
      expect(vm.state, isA<LobbyLoaded>(), reason: 'the old list stays visible');
    });

    test('an invitation event reloads the list and is remembered once', () async {
      await vm.load();
      rooms.add(roomJson('r4', 'New plans', isPublic: false, ownerId: 'u-carol', joined: false, invited: true));
      final invite = Invite(room: RoomSummary.fromJson(rooms.last), from: 'carol');
      transport.emit(InviteArrived(invite));
      await settle();
      expect(vm.latestInvite?.from, 'carol');
      expect((vm.state as LobbyLoaded).invitations.map((r) => r.name), ['Plans', 'New plans']);
    });

    test('being removed, a closed room, and reconnecting all refresh the list', () async {
      await vm.load();
      final before = transport.requests.where((r) => r.$1 == 'rooms:list').length;
      transport.emit(const Kicked('r1'));
      transport.emit(const RoomClosed('r2'));
      transport.emit(const Connected());
      await settle();
      final after = transport.requests.where((r) => r.$1 == 'rooms:list').length;
      expect(after - before, 3);
    });

    test('a slow, older answer cannot overwrite a newer one', () async {
      final gate = Completer<void>();
      var calls = 0;
      transport.onRequest = null;
      final slow = FakeTransport();
      // First call is held back and returns an OLD list; the second returns the new one.
      final svc = _GatedService(slow, gate, () => calls++);
      final lobby = LobbyViewModel(svc, slow.events);
      addTearDown(lobby.dispose);
      final first = lobby.load(); // old answer, delayed
      await settle();
      final second = lobby.load(); // newer answer, immediate
      await second;
      gate.complete();
      await first;
      expect((lobby.state as LobbyLoaded).rooms.single.name, 'NEW');
    });
  });

  group('RoomViewModel', () {
    late FakeTransport transport;
    late RoomViewModel vm;
    final mine = room('r1', 'Garden'); // owner u-alice

    Future<RoomViewModel> open({RoomSummary? summary, String user = 'u-alice', List<Map<String, Object?>>? history}) async {
      final history0 = history ?? [messageJson('r1', 1, 'one'), messageJson('r1', 2, 'two')];
      transport = FakeTransport(
        onRequest: (event, payload) => switch (event) {
          'room:history' when payload['afterSeq'] == null => Ok({'ok': true, 'messages': history0}),
          'room:history' => Ok({
            'ok': true,
            'messages': [for (final m in _all) if ((m['seq']! as int) > (payload['afterSeq']! as int)) m],
          }),
          'room:members' => Ok({
            'ok': true,
            'members': [
              {'id': 'u-alice', 'username': 'alice', 'isOwner': true, 'online': true},
              {'id': 'u-bob', 'username': 'bob', 'isOwner': false, 'online': false},
            ],
          }),
          'room:send' => Ok({'ok': true, 'message': messageJson('r1', _nextSeq, payload['text']! as String)}),
          _ => null,
        },
      );
      _all
        ..clear()
        ..addAll(history0);
      final v = RoomViewModel(
        room: summary ?? mine,
        currentUserId: user,
        service: RelayService(transport),
        events: transport.events,
      );
      addTearDown(v.dispose);
      await v.load();
      return v;
    }

    List<ChatMessage> shown(RoomViewModel v) => (v.state as RoomActive).messages;

    test('opens with the latest history and the member list', () async {
      vm = await open();
      expect(shown(vm).map((m) => m.text), ['one', 'two']);
      expect(vm.lastSeq, 2);
      expect((vm.state as RoomActive).members.map((m) => m.username), ['alice', 'bob']);
      expect(vm.isOwner, isTrue);
      expect((await open(user: 'u-bob')).isOwner, isFalse);
    });

    test('a live message is appended once, even if it arrives twice', () async {
      vm = await open();
      final m3 = message('r1', 3, 'three');
      transport.emit(MessageArrived(m3));
      transport.emit(MessageArrived(m3)); // duplicate
      await settle();
      expect(shown(vm).map((m) => m.seq), [1, 2, 3]);
      transport.emit(MessageArrived(message('r2', 1, 'other room')));
      await settle();
      expect(shown(vm), hasLength(3), reason: 'messages for other rooms are ignored');
    });

    test('my own send appears at once and is not doubled by the broadcast', () async {
      vm = await open();
      _nextSeq = 3;
      expect(await vm.send('hello'), isA<Ok<void>>());
      transport.emit(MessageArrived(message('r1', 3, 'hello'))); // the broadcast
      await settle();
      expect(shown(vm).map((m) => m.text), ['one', 'two', 'hello']);
    });

    test('a failed send reports the problem and adds nothing', () async {
      vm = await open();
      transport.onRequest = (event, _) => const Err('rate_limited', 'Slow down.');
      final result = await vm.send('hello');
      expect((result as Err).message, 'Slow down.');
      expect(shown(vm), hasLength(2));
    });

    test('a gap in sequence numbers triggers a catch-up', () async {
      vm = await open();
      _all.addAll([messageJson('r1', 3, 'three'), messageJson('r1', 4, 'four')]);
      transport.emit(MessageArrived(message('r1', 4, 'four'))); // 3 was missed
      await settle();
      await settle();
      expect(shown(vm).map((m) => m.seq), [1, 2, 3, 4]);
      expect(vm.lastSeq, 4);
      final asked = transport.requests.where((r) => r.$1 == 'room:history' && r.$2.containsKey('afterSeq'));
      expect(asked.single.$2['afterSeq'], 2, reason: 'asked after the last number seen BEFORE the gap');
    });

    test('after a reconnect the room asks for what it missed', () async {
      vm = await open();
      transport.emit(const Disconnected('transport close'));
      _all.addAll([messageJson('r1', 3, 'while away'), messageJson('r1', 4, 'also missed')]);
      transport.emit(const Connected());
      await settle();
      await settle();
      expect(shown(vm).map((m) => m.text), ['one', 'two', 'while away', 'also missed']);
      writeCaptured(
        'relay_ch25_catch_up.txt',
        'the room showed seq 1 and 2, then the connection dropped and came back.\n'
            'requests sent after the reconnect:\n'
            '${transport.requests.skip(2).map((r) => '  ${r.$1} ${r.$2}').join('\n')}\n'
            'the room now shows: ${shown(vm).map((m) => '#${m.seq} "${m.text}"').join(', ')}',
      );
    });

    test('being removed or the room closing ends the room', () async {
      vm = await open();
      transport.emit(const Kicked('r1'));
      await settle();
      expect((vm.state as RoomEnded).reason, contains('removed'));

      vm = await open();
      transport.emit(const RoomClosed('r1'));
      await settle();
      expect((vm.state as RoomEnded).reason, contains('closed'));

      vm = await open();
      transport.emit(const Kicked('some-other-room'));
      await settle();
      expect(vm.state, isA<RoomActive>());
    });

    test('a membership change refreshes the member list', () async {
      vm = await open();
      final before = transport.requests.where((r) => r.$1 == 'room:members').length;
      transport.emit(const RoomChanged('r1', 'joined', 'carol'));
      await settle();
      expect(transport.requests.where((r) => r.$1 == 'room:members').length, before + 1);
    });

    test('owner actions call the right events', () async {
      vm = await open();
      await vm.invite('carol');
      await vm.kick('bob');
      await vm.close();
      await vm.leave();
      final events = transport.requests.map((r) => r.$1).toList();
      expect(events, containsAllInOrder(['room:invite', 'room:kick', 'room:members', 'room:close', 'room:leave']));
    });

    test('failing to load history is an error state', () async {
      transport = FakeTransport(onRequest: (_, _) => const Err('not_found', 'No such room.'));
      final v = RoomViewModel(
        room: mine,
        currentUserId: 'u-alice',
        service: RelayService(transport),
        events: transport.events,
      );
      addTearDown(v.dispose);
      await v.load();
      expect((v.state as RoomFailed).message, 'No such room.');
    });
  });
}

final _all = <Map<String, Object?>>[];
int _nextSeq = 3;

Future<SavedSessionOrNull> memoryStoreRead(SessionViewModel vm) => vm.store.read();

typedef SavedSessionOrNull = dynamic;

/// A service whose first room list is delayed and old, the second immediate and new.
class _GatedService extends RelayService {
  _GatedService(super.transport, this.gate, this.count);
  final Completer<void> gate;
  final int Function() count;

  @override
  Future<Result<List<RoomSummary>>> listRooms() async {
    final call = count();
    if (call == 0) {
      await gate.future;
      return Ok([room('r1', 'OLD')]);
    }
    return Ok([room('r1', 'NEW')]);
  }
}
