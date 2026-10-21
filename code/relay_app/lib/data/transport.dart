import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/result.dart';
import 'models.dart';

// #docregion events
/// Everything the connection can tell the app, as one sealed family.
sealed class TransportEvent {
  const TransportEvent();
}

final class Connected extends TransportEvent {
  const Connected();
}

final class Disconnected extends TransportEvent {
  const Disconnected(this.reason);
  final String reason;
}

/// The connection could not be made. [unauthorized] means the server refused
/// the token, which is different from the server being unreachable.
final class ConnectFailed extends TransportEvent {
  const ConnectFailed({required this.unauthorized, required this.detail});
  final bool unauthorized;
  final String detail;
}

final class MessageArrived extends TransportEvent {
  const MessageArrived(this.message);
  final ChatMessage message;
}

final class RoomChanged extends TransportEvent {
  const RoomChanged(this.roomId, this.reason, this.username);
  final String roomId;
  final String reason; // joined, left, removed
  final String username;
}

final class Kicked extends TransportEvent {
  const Kicked(this.roomId);
  final String roomId;
}

final class RoomClosed extends TransportEvent {
  const RoomClosed(this.roomId);
  final String roomId;
}

final class InviteArrived extends TransportEvent {
  const InviteArrived(this.invite);
  final Invite invite;
}

final class SessionExpired extends TransportEvent {
  const SessionExpired();
}
// #enddocregion events

// #docregion transport
/// The connection to the server. The app depends on this interface only, so
/// the tests can replace the network with a fake.
abstract interface class RelayTransport {
  Stream<TransportEvent> get events;
  bool get isConnected;

  /// Starts connecting (and reconnecting by itself if the link drops).
  void connect(Uri baseUri, String token);

  /// Closes the connection and stops reconnecting.
  void disconnect();

  /// Sends [event] and waits for the server's acknowledgement.
  Future<Result<Map<String, Object?>>> request(
    String event, [
    Map<String, Object?> payload = const {},
  ]);
}
// #enddocregion transport

// #docregion parsereply
/// Turns the server's acknowledgement into a result. The server always sends
/// `{ok: true, ...}` or `{ok: false, code, message}`; anything else is treated
/// as a damaged answer.
Result<Map<String, Object?>> parseReply(Object? reply) {
  if (reply is Map<Object?, Object?>) {
    final data = {for (final e in reply.entries) '${e.key}': e.value};
    if (data['ok'] == true) return Ok(data);
    final code = data['code'];
    final message = data['message'];
    if (data['ok'] == false && code is String && message is String) {
      return Err(code, message);
    }
  }
  return const Err('bad_response', 'The server sent an unexpected answer.');
}
// #enddocregion parsereply

// #docregion socketio
class SocketIoTransport implements RelayTransport {
  SocketIoTransport({
    this.ackTimeout = const Duration(seconds: 8),
    this.reconnectDelayMs = 1000,
  });

  final Duration ackTimeout;
  final int reconnectDelayMs;
  final _events = StreamController<TransportEvent>.broadcast();
  io.Socket? _socket;

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  bool get isConnected => _socket?.connected ?? false;

  @override
  void connect(Uri baseUri, String token) {
    disconnect(); // never keep two connections
    final socket = io.io(
      baseUri.toString(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token}) // checked by the server's handshake
          .disableAutoConnect() // attach handlers first, then connect
          .enableForceNew()
          .setReconnectionDelay(reconnectDelayMs)
          .setReconnectionDelayMax(reconnectDelayMs * 5)
          .build(),
    );
    socket
      ..onConnect((_) => _emit(const Connected()))
      ..onDisconnect((reason) => _emit(Disconnected('$reason')))
      ..onConnectError((error) {
        final text = '$error';
        _emit(
          ConnectFailed(
            unauthorized: text.contains('unauthorized'),
            detail: text,
          ),
        );
      })
      ..on('room:message', (data) => _parse(() => MessageArrived(ChatMessage.fromJson(data))))
      ..on('room:changed', (data) => _parse(() => switch (data) {
        {'roomId': String id, 'reason': String reason, 'username': String name} =>
          RoomChanged(id, reason, name),
        _ => throw FormatException('Bad room:changed $data'),
      }))
      ..on('room:kicked', (data) => _parse(() => switch (data) {
        {'roomId': String id} => Kicked(id),
        _ => throw FormatException('Bad room:kicked $data'),
      }))
      ..on('room:closed', (data) => _parse(() => switch (data) {
        {'roomId': String id} => RoomClosed(id),
        _ => throw FormatException('Bad room:closed $data'),
      }))
      ..on('invite:received', (data) => _parse(() => InviteArrived(Invite.fromJson(data))))
      ..on('session:expired', (_) => _emit(const SessionExpired()));
    _socket = socket;
    socket.connect();
  }

  void _emit(TransportEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// A malformed event from the server is ignored, not allowed to crash us.
  void _parse(TransportEvent Function() build) {
    try {
      _emit(build());
    } on FormatException {
      // dropped
    }
  }

  @override
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  @override
  Future<Result<Map<String, Object?>>> request(
    String event, [
    Map<String, Object?> payload = const {},
  ]) {
    final socket = _socket;
    // Refuse instead of letting the library queue the message for later.
    if (socket == null || !socket.connected) {
      return Future.value(const Err('network', 'Not connected to the server.'));
    }
    final done = Completer<Result<Map<String, Object?>>>();
    socket.emitWithAck(
      event,
      payload,
      ack: (Object? reply) {
        if (done.isCompleted) return;
        done.complete(parseReply(reply));
      },
    );
    return done.future.timeout(
      ackTimeout,
      onTimeout: () => const Err('timeout', 'The server took too long to answer.'),
    );
  }
}
// #enddocregion socketio
