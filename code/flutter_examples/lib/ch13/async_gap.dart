import 'package:flutter/material.dart';

Future<String> save() async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return 'saved';
}

// #docregion fixed
/// Safe: re-checks that the widget is still on screen after the await.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final result = await save();
        if (!context.mounted) return; // the screen may be gone by now
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result)));
      },
      child: const Text('Save'),
    );
  }
}
// #enddocregion fixed
