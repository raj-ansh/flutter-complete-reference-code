import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/result.dart';
import '../data/models.dart';
import '../state/lobby_view_model.dart';
import '../state/session_view_model.dart';
import 'connection_banner.dart';

// #docregion lobby
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  Invite? _announced;

  @override
  Widget build(BuildContext context) {
    final lobby = context.watch<LobbyViewModel>();
    final session = context.watch<SessionViewModel>().state;
    final user = session is SignedIn ? session.user : null;

    // Mention a new invitation once, in a snackbar, whatever else is on screen.
    final invite = lobby.latestInvite;
    if (invite != null && !identical(invite, _announced)) {
      _announced = invite;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${invite.from} invited you to "${invite.room.name}"')),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (_) => context.read<SessionViewModel>().signOut(),
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text('Signed in as ${user?.username ?? '?'}')),
              const PopupMenuItem(value: 'out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New room',
        onPressed: () => _createRoom(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: switch (lobby.state) {
              LobbyLoading() => const Center(child: CircularProgressIndicator()),
              LobbyFailed(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: lobby.load, child: const Text('Try again')),
                  ],
                ),
              ),
              LobbyLoaded() && final loaded => _RoomList(state: loaded),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createRoom(BuildContext context) async {
    final lobby = context.read<LobbyViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final choice = await showDialog<({String name, bool isPublic})>(
      context: context,
      builder: (_) => const _CreateRoomDialog(),
    );
    if (choice == null) return;
    final result = await lobby.createRoom(choice.name, isPublic: choice.isPublic);
    switch (result) {
      case Ok(:final value):
        router.push('/room/${value.id}');
      case Err(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList({required this.state});
  final LobbyLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.rooms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No rooms yet. Tap + to create the first one.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      children: [
        if (state.invitations.isNotEmpty) ...[
          const _Header('Invitations'),
          for (final r in state.invitations) _RoomTile(room: r),
        ],
        if (state.mine.isNotEmpty) ...[
          const _Header('Your rooms'),
          for (final r in state.mine) _RoomTile(room: r),
        ],
        if (state.others.isNotEmpty) ...[
          const _Header('Public rooms'),
          for (final r in state.others) _RoomTile(room: r),
        ],
        const SizedBox(height: 88),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});
  final RoomSummary room;

  @override
  Widget build(BuildContext context) {
    final lobby = context.read<LobbyViewModel>();
    return ListTile(
      leading: Icon(room.isPublic ? Icons.tag : Icons.lock_outline),
      title: Text(room.name),
      subtitle: Text('${room.memberCount} ${room.memberCount == 1 ? 'member' : 'members'}'),
      trailing: room.joined
          ? const Icon(Icons.chevron_right)
          : FilledButton.tonal(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                final result = await lobby.join(room);
                switch (result) {
                  case Ok():
                    router.push('/room/${room.id}');
                  case Err(:final message):
                    messenger.showSnackBar(SnackBar(content: Text(message)));
                }
              },
              child: Text(room.invited ? 'Accept' : 'Join'),
            ),
      onTap: room.joined ? () => context.push('/room/${room.id}') : null,
    );
  }
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _name = TextEditingController();
  bool _isPublic = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New room'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Anyone can join'),
            subtitle: Text(_isPublic ? 'Shown to everyone' : 'Invitation only'),
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (name: _name.text, isPublic: _isPublic)),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
// #enddocregion lobby
