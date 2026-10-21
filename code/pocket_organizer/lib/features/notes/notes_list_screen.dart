import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/list_screen_body.dart';
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
        heroTag: 'notes-fab', // see the note in the chapter: tags must differ
        onPressed: () => context.push('/notes/new'),
        tooltip: 'New note',
        child: const Icon(Icons.add),
      ),
      body: ListScreenBody<Note>(
        state: vm.state,
        onRetry: vm.load,
        onSearch: vm.search,
        searchHint: 'Search notes',
        emptyIcon: Icons.note_add_outlined,
        emptyTitle: 'No notes yet',
        emptyHint: 'Tap + to write your first note.',
        itemBuilder: (context, note) => _NoteTile(note: note),
      ),
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
        title: Text(
          note.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
