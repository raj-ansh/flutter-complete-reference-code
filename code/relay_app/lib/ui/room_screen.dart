import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/result.dart';
import '../data/models.dart';
import '../state/lobby_view_model.dart';
import '../state/room_view_model.dart';
import '../state/session_view_model.dart';
import 'connection_banner.dart';

// #docregion roomscreen
/// Finds the room's summary, then builds the view model that lives exactly as
/// long as this screen.
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context) {
    final room = context.read<LobbyViewModel>().byId(roomId);
    final session = context.read<SessionViewModel>();
    final state = session.state;
    final me = state is SignedIn ? state.user : null;
    if (room == null || me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This room is not available.'),
              TextButton(onPressed: () => context.go('/'), child: const Text('Back to rooms')),
            ],
          ),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => RoomViewModel(
        room: room,
        currentUserId: me.id,
        service: session.service,
        events: session.transport.events,
      )..load(),
      child: const _RoomView(),
    );
  }
}

class _RoomView extends StatelessWidget {
  const _RoomView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(vm.room.name),
        actions: [
          if (vm.state is RoomActive)
            IconButton(
              tooltip: 'Members',
              icon: const Icon(Icons.group),
              onPressed: () => _showMembers(context),
            ),
          if (vm.state is RoomActive)
            PopupMenuButton<String>(
              onSelected: (value) => _menu(context, value),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'invite', child: Text('Invite someone')),
                if (vm.isOwner)
                  const PopupMenuItem(value: 'close', child: Text('Close the room'))
                else
                  const PopupMenuItem(value: 'leave', child: Text('Leave the room')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: switch (vm.state) {
              RoomLoading() => const Center(child: CircularProgressIndicator()),
              RoomFailed(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    FilledButton(onPressed: vm.load, child: const Text('Try again')),
                  ],
                ),
              ),
              RoomEnded(:final reason) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(reason, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Back to rooms'),
                      ),
                    ],
                  ),
                ),
              ),
              RoomActive(:final messages) => _Messages(messages: messages),
            },
          ),
          if (vm.state is RoomActive) const _Composer(),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, String value) async {
    final vm = context.read<RoomViewModel>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (value) {
      case 'invite':
        final name = await _askName(context);
        if (name == null || name.trim().isEmpty) return;
        final result = await vm.invite(name);
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (result) {
              Ok() => 'Invitation sent to ${name.trim()}.',
              Err(:final message) => message,
            }),
          ),
        );
      case 'leave' || 'close':
        final sure = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(value == 'close' ? 'Close this room?' : 'Leave this room?'),
            content: Text(
              value == 'close'
                  ? 'Everyone will be removed. This cannot be undone.'
                  : 'You can join again later if the room is public or you are invited.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(value == 'close' ? 'Close room' : 'Leave'),
              ),
            ],
          ),
        );
        if (sure != true) return;
        final result = await (value == 'close' ? vm.close() : vm.leave());
        switch (result) {
          case Ok():
            router.go('/');
          case Err(:final message):
            messenger.showSnackBar(SnackBar(content: Text(message)));
        }
    }
  }

  Future<String?> _askName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite someone'),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }

  void _showMembers(BuildContext context) {
    final vm = context.read<RoomViewModel>();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const _MembersSheet(),
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({required this.messages});
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final state = context.read<SessionViewModel>().state;
    final me = state is SignedIn ? state.user.id : '';
    if (messages.isEmpty) {
      return const Center(child: Text('No messages yet. Say hello!'));
    }
    // reverse: true keeps the newest message at the bottom, next to the box.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[messages.length - 1 - i];
        return _Bubble(message: m, mine: m.userId == me);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                message.username,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.primary),
              ),
            Text(message.text),
            Text(
              DateFormat.jm().format(message.at.toLocal()),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _field = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _field.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await context.read<RoomViewModel>().send(text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      switch (result) {
        case Ok():
          _field.clear(); // only a message the server accepted is cleared
        case Err(:final message):
          _error = message; // the text stays, so the user can try again
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _field,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Message'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  tooltip: 'Send',
                  icon: const Icon(Icons.send),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersSheet extends StatelessWidget {
  const _MembersSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomViewModel>();
    final members = switch (vm.state) {
      RoomActive(:final members) => members,
      _ => const <Member>[],
    };
    final state = context.read<SessionViewModel>().state;
    final me = state is SignedIn ? state.user.id : '';
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final m in members)
            ListTile(
              leading: Icon(
                Icons.circle,
                size: 12,
                color: m.online ? Colors.green : Colors.grey,
                semanticLabel: m.online ? 'online' : 'offline',
              ),
              title: Text(m.isOwner ? '${m.username} (owner)' : m.username),
              trailing: vm.isOwner && m.id != me
                  ? IconButton(
                      tooltip: 'Remove ${m.username}',
                      icon: const Icon(Icons.person_remove),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final result = await vm.kick(m.username);
                        if (result is Err<void>) {
                          messenger.showSnackBar(SnackBar(content: Text(result.message)));
                        }
                      },
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
// #enddocregion roomscreen
