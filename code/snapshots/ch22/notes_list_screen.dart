import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/state_views.dart';
import 'note.dart';
import 'notes_view_model.dart';

// #docregion list
class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotesViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/notes/new'),
        tooltip: 'New note',
        child: const Icon(Icons.add),
      ),
      body: switch (vm.state) {
        NotesLoading() => const Center(child: CircularProgressIndicator()),
        NotesFailed(:final message) => ErrorState(
          message: message,
          onRetry: vm.load,
        ),
        NotesLoaded() && final loaded => _NotesBody(state: loaded),
      },
    );
  }
}

class _NotesBody extends StatelessWidget {
  const _NotesBody({required this.state});
  final NotesLoaded state;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<NotesViewModel>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            hintText: 'Search notes',
            leading: const Icon(Icons.search),
            onChanged: vm.search,
          ),
        ),
        if (state.message != null)
          MaterialBanner(
            content: Text(state.message!),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(
          child: state.notes.isEmpty
              ? (state.isSearching
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'No matching notes',
                        hint: 'Try a different word.',
                      )
                    : const EmptyState(
                        icon: Icons.note_add_outlined,
                        title: 'No notes yet',
                        hint: 'Tap + to write your first note.',
                      ))
              : ListView.builder(
                  itemCount: state.notes.length,
                  itemBuilder: (context, i) =>
                      _NoteTile(note: state.notes[i]),
                ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<NotesViewModel>();
    return Dismissible(
      // A key that identifies the note, not its position in the list.
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final removed = await vm.delete(note);
        if (removed == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted "${note.displayTitle}"'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => vm.undoDelete(removed),
              ),
            ),
          );
      },
      child: ListTile(
        title: Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          note.body.trim().isEmpty ? 'No text' : note.body.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: note.pinned ? 'Unpin' : 'Pin',
          icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
          onPressed: () => vm.togglePin(note),
        ),
        onTap: () => context.push('/notes/${note.id}'),
      ),
    );
  }
}
// #enddocregion list
