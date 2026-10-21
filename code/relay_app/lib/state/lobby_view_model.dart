import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/models.dart';
import '../data/relay_service.dart';
import '../data/transport.dart';

// #docregion lobbystate
sealed class LobbyState {
  const LobbyState();
}

final class LobbyLoading extends LobbyState {
  const LobbyLoading();
}

final class LobbyLoaded extends LobbyState {
  const LobbyLoaded(this.rooms);
  final List<RoomSummary> rooms;

  /// Rooms the user belongs to.
  List<RoomSummary> get mine => [for (final r in rooms) if (r.joined) r];

  /// Rooms the user was invited to and has not joined.
  List<RoomSummary> get invitations => [
    for (final r in rooms) if (r.invited && !r.joined) r,
  ];

  /// Public rooms the user has not joined.
  List<RoomSummary> get others => [
    for (final r in rooms) if (!r.joined && !r.invited) r,
  ];
}

final class LobbyFailed extends LobbyState {
  const LobbyFailed(this.message);
  final String message;
}
// #enddocregion lobbystate

// #docregion lobbyvm
class LobbyViewModel extends ChangeNotifier {
  LobbyViewModel(this._service, Stream<TransportEvent> events) {
    _events = events.listen(_onEvent);
  }

  final RelayService _service;
  late final StreamSubscription<TransportEvent> _events;

  LobbyState _state = const LobbyLoading();
  LobbyState get state => _state;

  /// Set when an invitation arrives, so the screen can mention it once.
  Invite? latestInvite;

  bool _disposed = false;
  int _generation = 0;

  RoomSummary? byId(String id) => switch (_state) {
    LobbyLoaded(:final rooms) => rooms.where((r) => r.id == id).firstOrNull,
    _ => null,
  };

  Future<void> load() async {
    if (_state is! LobbyLoaded) _set(const LobbyLoading());
    await _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final result = await _service.listRooms();
    if (generation != _generation) return; // an older answer arrived late
    switch (result) {
      case Ok(:final value):
        _set(LobbyLoaded(value));
      case Err(:final message):
        // Keep showing the old list if we have one.
        if (_state is! LobbyLoaded) _set(LobbyFailed(message));
    }
  }

  Future<Result<RoomSummary>> createRoom(String name, {required bool isPublic}) async {
    final result = await _service.createRoom(name, isPublic: isPublic);
    if (result is Ok) await _reload();
    return result;
  }

  Future<Result<RoomSummary>> join(RoomSummary room) async {
    final result = await _service.join(room.id);
    if (result is Ok) await _reload();
    return result;
  }

  void _onEvent(TransportEvent event) {
    switch (event) {
      case InviteArrived(:final invite):
        latestInvite = invite;
        _reload();
      case Connected() || Kicked() || RoomClosed() || RoomChanged():
        // Anything that may have changed the list: ask the server again.
        _reload();
      default:
        break;
    }
  }

  void _set(LobbyState state) {
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
// #enddocregion lobbyvm
