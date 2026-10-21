import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/models.dart';
import '../data/relay_service.dart';
import '../data/transport.dart';

// #docregion roomstate
sealed class RoomState {
  const RoomState();
}

final class RoomLoading extends RoomState {
  const RoomLoading();
}

final class RoomFailed extends RoomState {
  const RoomFailed(this.message);
  final String message;
}

/// The room is open. [messages] are oldest first and have increasing seq.
final class RoomActive extends RoomState {
  const RoomActive({required this.messages, required this.members});
  final List<ChatMessage> messages;
  final List<Member> members;
}

/// The room ended for this user (removed, or the owner closed it).
final class RoomEnded extends RoomState {
  const RoomEnded(this.reason);
  final String reason;
}
// #enddocregion roomstate

// #docregion roomvm
class RoomViewModel extends ChangeNotifier {
  RoomViewModel({
    required this.room,
    required this.currentUserId,
    required this._service,
    required Stream<TransportEvent> events,
  }) {
    _events = events.listen(_onEvent);
  }

  final RoomSummary room;
  final String currentUserId;
  final RelayService _service;
  late final StreamSubscription<TransportEvent> _events;

  RoomState _state = const RoomLoading();
  RoomState get state => _state;

  bool get isOwner => room.ownerId == currentUserId;

  final List<ChatMessage> _messages = [];
  List<Member> _members = const [];
  int _lastSeq = 0;
  bool _disposed = false;
  bool _catchingUp = false;

  /// The highest sequence number seen in this room.
  int get lastSeq => _lastSeq;

  Future<void> load() async {
    final history = await _service.history(room.id);
    switch (history) {
      case Err(:final message):
        return _set(RoomFailed(message));
      case Ok(:final value):
        _messages
          ..clear()
          ..addAll(value);
        _lastSeq = value.isEmpty ? 0 : value.last.seq;
    }
    await _loadMembers();
    _publish();
  }

  Future<void> _loadMembers() async {
    final result = await _service.members(room.id);
    if (result is Ok<List<Member>>) _members = result.value;
  }

  /// Adds messages we have not seen. A message is new only if its number is
  /// higher than the last one, so a message that arrives twice (once as the
  /// reply to our own send and once as a broadcast) is shown once.
  void _add(ChatMessage message) {
    if (message.seq <= _lastSeq) return;
    final before = _lastSeq;
    final gap = message.seq > before + 1;
    _messages.add(message);
    _lastSeq = message.seq;
    // We skipped some numbers: fetch what lies between. The request must start
    // from where we were BEFORE this message, or the missing ones are never asked for.
    if (gap) _catchUp(after: before);
  }

  /// Asks for everything after [after] (default: the last message we have)
  /// and merges it in, ignoring numbers we already hold.
  Future<void> _catchUp({int? after}) async {
    if (_catchingUp) return;
    _catchingUp = true;
    try {
      final result = await _service.history(room.id, afterSeq: after ?? _lastSeq);
      if (result is Ok<List<ChatMessage>>) {
        final have = {for (final m in _messages) m.seq};
        _messages.addAll(result.value.where((m) => !have.contains(m.seq)));
        _messages.sort((a, b) => a.seq.compareTo(b.seq));
        if (_messages.isNotEmpty) _lastSeq = _messages.last.seq;
        _publish();
      }
    } finally {
      _catchingUp = false;
    }
  }

  void _onEvent(TransportEvent event) {
    switch (event) {
      case MessageArrived(:final message) when message.roomId == room.id:
        _add(message);
        _publish();
      case Connected() when _state is RoomActive:
        _catchUp(); // after a reconnect: fetch what we missed while away
      case RoomChanged(:final roomId) when roomId == room.id:
        _loadMembers().then((_) => _publish());
      case Kicked(:final roomId) when roomId == room.id:
        _set(const RoomEnded('You were removed from this room.'));
      case RoomClosed(:final roomId) when roomId == room.id:
        _set(const RoomEnded('The owner closed this room.'));
      default:
        break;
    }
  }

  Future<Result<void>> send(String text) async {
    final result = await _service.send(room.id, text);
    switch (result) {
      case Ok(:final value):
        _add(value); // also arrives as a broadcast; _add ignores the second
        _publish();
        return const Ok(null);
      case Err(:final code, :final message):
        return Err(code, message);
    }
  }

  Future<Result<void>> invite(String username) =>
      _service.invite(room.id, username);

  Future<Result<void>> kick(String username) async {
    final result = await _service.kick(room.id, username);
    if (result is Ok) await _loadMembers();
    _publish();
    return result;
  }

  Future<Result<void>> close() => _service.close(room.id);

  Future<Result<void>> leave() => _service.leave(room.id);

  void _publish() {
    if (_state is RoomEnded || _state is RoomFailed && _messages.isEmpty) {
      notifyListeners();
      return;
    }
    _set(RoomActive(messages: List.unmodifiable(_messages), members: _members));
  }

  void _set(RoomState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events.cancel();
    super.dispose();
  }
}
// #enddocregion roomvm
