import 'package:flutter/material.dart';

// #docregion dismissible
/// A list whose items can be swiped away.
class SwipeList extends StatefulWidget {
  const SwipeList({super.key});

  @override
  State<SwipeList> createState() => _SwipeListState();
}

class _SwipeListState extends State<SwipeList> {
  final List<String> _tasks = ['Water tomatoes', 'Prune roses', 'Buy compost'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final task in _tasks)
          Dismissible(
            // Each item needs a unique key so Flutter knows which one left.
            key: ValueKey(task),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Theme.of(context).colorScheme.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete),
            ),
            onDismissed: (direction) {
              setState(() => _tasks.remove(task));
            },
            child: ListTile(title: Text(task)),
          ),
      ],
    );
  }
}
// #enddocregion dismissible
