import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

// #docregion messages
/// A message as the server sends it. Parsed strictly, like any network data.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.from,
    required this.text,
    required this.at,
  });

  final int id;
  final String from;
  final String text;
  final DateTime at;

  factory ChatMessage.fromJson(Object? json) {
    return switch (json) {
      {'id': int id, 'from': String from, 'text': String text, 'at': int at} =>
        ChatMessage(
          id: id,
          from: from,
          text: text,
          at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
        ),
      _ => throw FormatException('Unexpected message shape: $json'),
    };
  }
}

/// Everything the UI can learn from the connection, as one sealed family.
sealed class ChatEvent {
  const ChatEvent();
}

final class Connected extends ChatEvent {
  const Connected();
}

final class Disconnected extends ChatEvent {
  const Disconnected(this.reason);
  final String reason;
}

final class ConnectFailed extends ChatEvent {
  const ConnectFailed(this.error);
  final String error;
}

final class MessageReceived extends ChatEvent {
  const MessageReceived(this.message);
  final ChatMessage message;
}

/// The outcome of sending, including the server's acknowledgement.
sealed class SendResult {
  const SendResult();
}

final class Sent extends SendResult {
  const Sent(this.id);
  final int id;
}

final class Rejected extends SendResult {
  const Rejected(this.reason);
  final String reason;
}

final class SendFailed extends SendResult {
  const SendFailed(this.reason);
  final String reason;
}
// #enddocregion messages

// #docregion transport
/// What the UI needs from a real-time connection. The UI depends on this
/// interface, so tests can replace the network with a fake.
abstract interface class ChatTransport {
  Stream<ChatEvent> get events;
  bool get isConnected;
  void connect();
  Future<SendResult> send(String text);
  void dispose();
}
// #enddocregion transport

// #docregion socketio
class SocketIoTransport implements ChatTransport {
  SocketIoTransport(
    String url, {
    this.ackTimeout = const Duration(seconds: 5),
    int reconnectDelayMs = 500,
  }) : _socket = io.io(
         url,
         io.OptionBuilder()
             .setTransports(['websocket']) // required on Flutter (not web)
             .disableAutoConnect() // we call connect() once handlers exist
             .enableForceNew() // a private connection, not a cached one
             .setReconnectionDelay(reconnectDelayMs)
             .setReconnectionDelayMax(reconnectDelayMs * 4)
             .build(),
       ) {
    _socket
      ..onConnect((_) => _events.add(const Connected()))
      ..onDisconnect((reason) => _events.add(Disconnected('$reason')))
      ..onConnectError((error) => _events.add(ConnectFailed('$error')))
      ..on('chat:message', _onMessage);
  }

  final io.Socket _socket;
  final Duration ackTimeout;
  final _events = StreamController<ChatEvent>.broadcast();

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  bool get isConnected => _socket.connected;

  @override
  void connect() => _socket.connect();

  void _onMessage(Object? data) {
    try {
      _events.add(MessageReceived(ChatMessage.fromJson(data)));
    } on FormatException {
      // Ignore malformed messages instead of crashing the whole connection.
    }
  }

  @override
  Future<SendResult> send(String text) {
    // The library would silently buffer an emit made while offline and send
    // it after a reconnect. This app chooses to refuse instead.
    if (!_socket.connected) {
      return Future.value(const SendFailed('Not connected'));
    }
    final done = Completer<SendResult>();
    _socket.emitWithAck(
      'chat:send',
      {'text': text},
      ack: (Object? reply) {
        if (done.isCompleted) return;
        done.complete(switch (reply) {
          {'ok': true, 'id': int id} => Sent(id),
          {'ok': false, 'error': String error} => Rejected(error),
          _ => const SendFailed('Unreadable acknowledgement'),
        });
      },
    );
    return done.future.timeout(
      ackTimeout,
      onTimeout: () => const SendFailed('No acknowledgement from the server'),
    );
  }

  @override
  void dispose() {
    _socket.dispose();
    _events.close();
  }
}
// #enddocregion socketio
