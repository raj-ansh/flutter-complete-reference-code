import 'package:flutter/material.dart';

// #docregion undo
/// Delete with Undo: no confirmation dialog, because the action is reversible.
class UndoList extends StatefulWidget {
  const UndoList({super.key});

  @override
  State<UndoList> createState() => _UndoListState();
}

class _UndoListState extends State<UndoList> {
  final List<String> _notes = ['Water tomatoes', 'Prune roses', 'Buy compost'];

  void _delete(int index) {
    final removed = _notes[index];
    setState(() => _notes.removeAt(index));

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar() // do not queue a pile of messages
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "$removed"'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setState(() => _notes.insert(index, removed)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _notes.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(_notes[i]),
          trailing: IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(i),
          ),
        ),
      ),
    );
  }
}
// #enddocregion undo

// #docregion sheet
/// A modal bottom sheet that returns the chosen sort order.
class SheetDemo extends StatefulWidget {
  const SheetDemo({super.key});

  @override
  State<SheetDemo> createState() => _SheetDemoState();
}

class _SheetDemoState extends State<SheetDemo> {
  String _sort = 'name';

  Future<void> _pick() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        // A sheet is limited to 9/16 of the screen height; scrolling keeps
        // longer content reachable instead of overflowing.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, // only as tall as its content
            children: [
              const ListTile(title: Text('Sort by')),
              for (final option in const ['name', 'date', 'size'])
                ListTile(
                  leading: Icon(option == _sort ? Icons.check : null),
                  title: Text(option),
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    setState(() => _sort = choice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sorted by $_sort'),
            OutlinedButton(onPressed: _pick, child: const Text('Sort...')),
          ],
        ),
      ),
    );
  }
}
// #enddocregion sheet

// #docregion banner
/// A banner stays until dismissed, for something that needs attention.
void showOfflineBanner(BuildContext context) {
  ScaffoldMessenger.of(context).showMaterialBanner(
    MaterialBanner(
      content: const Text('You are offline. Changes will sync later.'),
      leading: const Icon(Icons.cloud_off),
      actions: [
        TextButton(
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          child: const Text('Dismiss'),
        ),
      ],
    ),
  );
}
// #enddocregion banner
