import 'package:flutter/material.dart';

import 'state.dart';


// #docregion view
/// A "dumb" view: it receives a state and callbacks, and holds no logic and
/// no knowledge of which state-management approach drives it.
class PantryView extends StatelessWidget {
  const PantryView({
    super.key,
    required this.state,
    required this.onToggle,
    required this.onAdd,
    required this.onRetry,
  });

  final PantryState state;
  final void Function(int index) onToggle;
  final VoidCallback onAdd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      PantryLoading() => const Center(child: CircularProgressIndicator()),
      PantryFailed(:final message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(message, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
      PantryLoaded(:final items, :final message) => Column(
        children: [
          if (message != null)
            MaterialBanner(content: Text(message), actions: const [SizedBox()]),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => CheckboxListTile(
                value: items[i].bought,
                onChanged: (_) => onToggle(i),
                title: Text(items[i].name),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(onPressed: onAdd, child: const Text('Add eggs')),
          ),
        ],
      ),
    };
  }
}
// #enddocregion view
