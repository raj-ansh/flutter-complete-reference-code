import 'package:flutter/material.dart';

// #docregion states
/// Everything a list screen can be. Each case carries only the data that
/// makes sense for it, and a switch over it must handle all four.
sealed class ListState<T> {
  const ListState();
}

class Loading<T> extends ListState<T> {
  const Loading();
}

class Failed<T> extends ListState<T> {
  const Failed(this.message);
  final String message;
}

class Loaded<T> extends ListState<T> {
  const Loaded(this.items);
  final List<T> items;
}

/// Renders a [ListState] of strings; the compiler checks every case.
class StateView extends StatelessWidget {
  const StateView({super.key, required this.state, this.onRetry});

  final ListState<String> state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      Loading() => const Center(child: CircularProgressIndicator()),
      Failed(:final message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 8),
            Text(message),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
      Loaded(:final items) when items.isEmpty => const Center(
        child: Text('Nothing here yet. Tap + to add your first item.'),
      ),
      Loaded(:final items) => ListView(
        children: [for (final item in items) ListTile(title: Text(item))],
      ),
    };
  }
}
// #enddocregion states

/// All four states side by side, for a screenshot.
class StatesGallery extends StatelessWidget {
  const StatesGallery({super.key});

  @override
  Widget build(BuildContext context) {
    Widget panel(String title, ListState<String> state) {
      return Card.outlined(
        child: SizedBox(
          height: 170,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Expanded(
                child: StateView(state: state, onRetry: () {}),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        panel('Loading', const Loading()),
        panel('Failed', const Failed('Could not load. Check your connection.')),
        panel('Empty', const Loaded([])),
        panel('Loaded', const Loaded(['Tomatoes', 'Basil', 'Mint'])),
      ],
    );
  }
}
