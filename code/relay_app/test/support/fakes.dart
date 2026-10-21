import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:relay_app/app.dart';
import 'package:relay_app/core/result.dart';
import 'package:relay_app/data/models.dart';
import 'package:relay_app/data/session_store.dart';
import 'package:relay_app/data/transport.dart';

// #docregion faketransport
/// A transport the test controls: it answers requests from a function and
/// raises events on demand. No sockets are involved.
class FakeTransport implements RelayTransport {
  FakeTransport({this.onRequest});

  /// Answers a request. Return null to get a plain `{ok: true}` reply.
  Result<Map<String, Object?>>? Function(String event, Map<String, Object?> payload)?
  onRequest;

  final _controller = StreamController<TransportEvent>.broadcast();
  final requests = <(String, Map<String, Object?>)>[];
  int connectCalls = 0;
  int disconnectCalls = 0;
  Uri? lastBase;
  String? lastToken;
  bool connected = false;

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  bool get isConnected => connected;

  @override
  void connect(Uri baseUri, String token) {
    connectCalls++;
    lastBase = baseUri;
    lastToken = token;
  }

  @override
  void disconnect() {
    disconnectCalls++;
    connected = false;
  }

  @override
  Future<Result<Map<String, Object?>>> request(
    String event, [
    Map<String, Object?> payload = const {},
  ]) async {
    requests.add((event, payload));
    return onRequest?.call(event, payload) ?? const Ok(<String, Object?>{'ok': true});
  }

  /// Raises an event as if the server had sent it. Pumping twice afterwards
  /// lets a widget see it (a stream delivers in a later microtask).
  void emit(TransportEvent event) {
    if (event is Connected) connected = true;
    if (event is Disconnected) connected = false;
    _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}
// #enddocregion faketransport

// JSON the real server would send, for the fakes to answer with.
Map<String, Object?> roomJson(
  String id,
  String name, {
  bool isPublic = true,
  String ownerId = 'u-alice',
  int members = 1,
  bool joined = true,
  bool invited = false,
}) => {
  'id': id,
  'name': name,
  'isPublic': isPublic,
  'ownerId': ownerId,
  'memberCount': members,
  'joined': joined,
  'invited': invited,
};

Map<String, Object?> messageJson(
  String roomId,
  int seq,
  String text, {
  String userId = 'u-alice',
  String username = 'alice',
}) => {
  'roomId': roomId,
  'seq': seq,
  'userId': userId,
  'username': username,
  'text': text,
  'at': 1792000000000 + seq * 60000,
};

ChatMessage message(String roomId, int seq, String text, {String userId = 'u-alice', String username = 'alice'}) =>
    ChatMessage.fromJson(messageJson(roomId, seq, text, userId: userId, username: username));

RoomSummary room(String id, String name, {String ownerId = 'u-alice', bool joined = true, bool invited = false, bool isPublic = true}) =>
    RoomSummary.fromJson(roomJson(id, name, ownerId: ownerId, joined: joined, invited: invited, isPublic: isPublic));

/// An HTTP client that answers the auth routes like the real server.
MockClient authClient({
  String username = 'alice',
  String password = 'a long enough password',
  Set<String> taken = const {},
  List<String>? log,
}) => MockClient((request) async {
  log?.add('${request.method} ${request.url.path}');
  http.Response json(int status, Map<String, Object?> body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  final body = request.body.isEmpty ? <String, Object?>{} : (jsonDecode(request.body) as Map).cast<String, Object?>();
  if (request.url.path == '/api/logout') return json(200, {'ok': true});
  final name = '${body['username']}'.toLowerCase();
  if (request.url.path == '/api/register') {
    if (taken.contains(name)) {
      return json(409, {'ok': false, 'code': 'conflict', 'message': 'That username is taken.'});
    }
    return json(200, {'ok': true, 'user': {'id': 'u-$name', 'username': name}, 'token': 'token-$name', 'expiresAt': 0});
  }
  if (name == username && body['password'] == password) {
    return json(200, {'ok': true, 'user': {'id': 'u-$name', 'username': name}, 'token': 'token-$name', 'expiresAt': 0});
  }
  return json(401, {'ok': false, 'code': 'unauthorized', 'message': 'Wrong username or password.'});
});

/// A store backed by the secure-storage mock, so no platform is needed.
SessionStore memoryStore([Map<String, String> initial = const {}]) {
  FlutterSecureStorage.setMockInitialValues(Map.of(initial));
  return SessionStore();
}

Map<String, String> savedSession({String username = 'alice', String url = 'http://10.0.2.2:3000'}) => {
  'relay.serverUrl': url,
  'relay.token': 'token-$username',
  'relay.userId': 'u-$username',
  'relay.username': username,
};

RelayDependencies depsWith({
  required FakeTransport transport,
  SessionStore? store,
  http.Client? client,
}) => RelayDependencies(
  store: store ?? memoryStore(),
  client: client ?? authClient(),
  transport: transport,
);

// #docregion fakebackend
/// A tiny in-memory stand-in for the server, enough for screen tests: it keeps
/// rooms and messages, answers the events, and broadcasts new messages back to
/// the transport the way the real server does.
class FakeBackend {
  FakeBackend(this.transport, {this.meId = 'u-alice', this.meName = 'alice'}) {
    transport.onRequest = handle;
  }

  final FakeTransport transport;
  final String meId;
  final String meName;
  final rooms = <Map<String, Object?>>[];
  final messages = <String, List<Map<String, Object?>>>{};
  final members = <String, List<Map<String, Object?>>>{};
  String? failNext; // make the next request fail with this code

  void addRoom(Map<String, Object?> room, {List<Map<String, Object?>> history = const []}) {
    rooms.add(room);
    messages[room['id']! as String] = [...history];
    members[room['id']! as String] = [
      {'id': room['ownerId'], 'username': room['ownerId'] == meId ? meName : 'owner', 'isOwner': true, 'online': true},
      if (room['joined'] == true && room['ownerId'] != meId)
        {'id': meId, 'username': meName, 'isOwner': false, 'online': true},
    ];
  }

  Result<Map<String, Object?>>? handle(String event, Map<String, Object?> p) {
    if (failNext != null) {
      final code = failNext!;
      failNext = null;
      return Err(code, 'Server said $code.');
    }
    final roomId = p['roomId'];
    switch (event) {
      case 'rooms:list':
        return Ok({'ok': true, 'rooms': rooms});
      case 'room:create':
        final id = 'room${rooms.length + 1}xxxx';
        addRoom(roomJson(id, p['name']! as String, isPublic: p['isPublic']! as bool, ownerId: meId));
        return Ok({'ok': true, 'room': rooms.last});
      case 'room:join':
        final room = rooms.firstWhere((r) => r['id'] == roomId);
        room['joined'] = true;
        room['invited'] = false;
        return Ok({'ok': true, 'room': room});
      case 'room:history':
        final after = p['afterSeq'] as int?;
        final all = messages[roomId] ?? [];
        return Ok({'ok': true, 'messages': after == null ? all : [for (final m in all) if ((m['seq']! as int) > after) m]});
      case 'room:members':
        return Ok({'ok': true, 'members': members[roomId] ?? []});
      case 'room:send':
        final list = messages[roomId]!;
        final m = messageJson(roomId! as String, list.length + 1, p['text']! as String, userId: meId, username: meName);
        list.add(m);
        // The real server also broadcasts to the sender; so does this.
        scheduleMicrotask(() => transport.emit(MessageArrived(ChatMessage.fromJson(m))));
        return Ok({'ok': true, 'message': m});
      default:
        return null; // invite, kick, close, leave: plain { ok: true }
    }
  }

  /// A message from somebody else, arriving live.
  void incoming(String roomId, String text, {String from = 'bob'}) {
    final list = messages[roomId]!;
    final m = messageJson(roomId, list.length + 1, text, userId: 'u-$from', username: from);
    list.add(m);
    transport.emit(MessageArrived(ChatMessage.fromJson(m)));
  }
}
// #enddocregion fakebackend
