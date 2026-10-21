import '../core/result.dart';
import 'models.dart';
import 'transport.dart';

// #docregion service
/// Typed operations over the connection. Each method sends one event and turns
/// the server's reply into models, or an [Err] that is safe to show.
class RelayService {
  RelayService(this.transport);

  final RelayTransport transport;

  Future<Result<List<RoomSummary>>> listRooms() => _list(
    'rooms:list',
    const {},
    'rooms',
    RoomSummary.fromJson,
  );

  Future<Result<RoomSummary>> createRoom(String name, {required bool isPublic}) =>
      _one('room:create', {'name': name, 'isPublic': isPublic}, 'room', RoomSummary.fromJson);

  Future<Result<RoomSummary>> join(String roomId) =>
      _one('room:join', {'roomId': roomId}, 'room', RoomSummary.fromJson);

  Future<Result<void>> leave(String roomId) => _done('room:leave', {'roomId': roomId});

  Future<Result<void>> invite(String roomId, String username) =>
      _done('room:invite', {'roomId': roomId, 'username': username});

  Future<Result<void>> kick(String roomId, String username) =>
      _done('room:kick', {'roomId': roomId, 'username': username});

  Future<Result<void>> close(String roomId) => _done('room:close', {'roomId': roomId});

  Future<Result<ChatMessage>> send(String roomId, String text) =>
      _one('room:send', {'roomId': roomId, 'text': text}, 'message', ChatMessage.fromJson);

  /// The latest messages, or (with [afterSeq]) those after a known number.
  Future<Result<List<ChatMessage>>> history(String roomId, {int? afterSeq}) => _list(
    'room:history',
    {'roomId': roomId, 'afterSeq': ?afterSeq},
    'messages',
    ChatMessage.fromJson,
  );

  Future<Result<List<Member>>> members(String roomId) =>
      _list('room:members', {'roomId': roomId}, 'members', Member.fromJson);

  Future<Result<void>> _done(String event, Map<String, Object?> payload) async {
    final reply = await transport.request(event, payload);
    return switch (reply) {
      Ok() => const Ok(null),
      Err(:final code, :final message) => Err(code, message),
    };
  }

  Future<Result<T>> _one<T>(
    String event,
    Map<String, Object?> payload,
    String key,
    T Function(Object?) parse,
  ) async {
    final reply = await transport.request(event, payload);
    switch (reply) {
      case Err(:final code, :final message):
        return Err(code, message);
      case Ok(:final value):
        try {
          return Ok(parse(value[key]));
        } on FormatException {
          return const Err('bad_response', 'The server sent an unexpected answer.');
        }
    }
  }

  Future<Result<List<T>>> _list<T>(
    String event,
    Map<String, Object?> payload,
    String key,
    T Function(Object?) parse,
  ) async {
    final reply = await transport.request(event, payload);
    switch (reply) {
      case Err(:final code, :final message):
        return Err(code, message);
      case Ok(:final value):
        final items = value[key];
        if (items is! List<Object?>) {
          return const Err('bad_response', 'The server sent an unexpected answer.');
        }
        try {
          return Ok([for (final item in items) parse(item)]);
        } on FormatException {
          return const Err('bad_response', 'The server sent an unexpected answer.');
        }
    }
  }
}
// #enddocregion service
