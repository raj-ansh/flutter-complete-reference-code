import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_transport.dart';

// #docregion screen
/// A minimal chat screen: connection status, messages, and a send box that
/// reports what the server said about each message.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.transport});
  final ChatTransport transport;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _field = TextEditingController();
  late final StreamSubscription<ChatEvent> _subscription;
  String _status = 'Connecting…';
  String? _problem;

  @override
  void initState() {
    super.initState();
    // Subscribe first, then connect, so the first event is not missed.
    _subscription = widget.transport.events.listen(_onEvent);
    widget.transport.connect();
  }

  void _onEvent(ChatEvent event) {
    setState(() {
      switch (event) {
        case Connected():
          _status = 'Connected';
        case Disconnected():
          _status = 'Offline, trying to reconnect…';
        case ConnectFailed():
          _status = 'Cannot reach the server, retrying…';
        case MessageReceived(:final message):
          _messages.add(message);
      }
    });
  }

  Future<void> _send() async {
    final text = _field.text;
    final result = await widget.transport.send(text);
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Sent():
          _field.clear();
          _problem = null;
        case Rejected(:final reason):
          _problem = 'Not sent: $reason';
        case SendFailed(:final reason):
          _problem = 'Not sent: $reason';
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel(); // stop listening before the State disappears
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: _status == 'Connected'
              ? Colors.green.shade100
              : Colors.amber.shade100,
          padding: const EdgeInsets.all(8),
          child: Text(_status),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final m in _messages)
                ListTile(title: Text(m.text), subtitle: Text(m.from)),
            ],
          ),
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _problem!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _field,
                  decoration: const InputDecoration(hintText: 'Message'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send),
                tooltip: 'Send',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
// #enddocregion screen
