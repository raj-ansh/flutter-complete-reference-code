import 'package:flutter/material.dart';

enum Fruit { apple, banana, cherry }

// #docregion functions
/// A yes/no question. Returns true, false, or null if dismissed.
Future<bool?> confirmDelete(BuildContext context, String what) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete note?'),
      content: Text('"$what" will be removed. This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

/// A choice among a few options. Returns the chosen value, or null.
Future<Fruit?> chooseFruit(BuildContext context) {
  return showDialog<Fruit>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Favorite fruit'),
      children: [
        for (final fruit in Fruit.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, fruit),
            child: Text(fruit.name),
          ),
      ],
    ),
  );
}

/// A dialog that collects text. The controller lives in a small State class
/// so it is disposed when the dialog closes.
Future<String?> askName(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _NameDialog(),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
// #enddocregion functions

// #docregion page
/// Shows each dialog and displays what came back.
class DialogsPage extends StatefulWidget {
  const DialogsPage({super.key});

  @override
  State<DialogsPage> createState() => _DialogsPageState();
}

class _DialogsPageState extends State<DialogsPage> {
  String _result = 'Nothing chosen yet';

  Future<void> _confirm() async {
    final yes = await confirmDelete(context, 'Water the tomatoes');
    // The page may have been closed while the dialog was open.
    if (!mounted) return;
    setState(
      () => _result = switch (yes) {
        true => 'Deleted',
        false => 'Kept',
        null => 'Dismissed without choosing',
      },
    );
  }

  Future<void> _choose() async {
    final fruit = await chooseFruit(context);
    if (!mounted) return;
    setState(
      () => _result = fruit == null ? 'No fruit' : 'Fruit: ${fruit.name}',
    );
  }

  Future<void> _ask() async {
    final name = await askName(context);
    if (!mounted) return;
    setState(() => _result = name == null ? 'No name' : 'Hello, $name');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(onPressed: _confirm, child: const Text('Confirm')),
            FilledButton(onPressed: _choose, child: const Text('Choose')),
            FilledButton(onPressed: _ask, child: const Text('Ask')),
            const SizedBox(height: 16),
            Text(_result),
          ],
        ),
      ),
    );
  }
}
// #enddocregion page
