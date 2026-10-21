import 'package:flutter/material.dart';

Future<String> save() async => 'saved';

class SaveButton extends StatelessWidget {
  const SaveButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final result = await save();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      },
      child: const Text('Save'),
    );
  }
}
