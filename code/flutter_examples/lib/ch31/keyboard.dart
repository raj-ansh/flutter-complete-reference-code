import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// #docregion keyboard
/// A list that can be used without touching the screen: Ctrl+N adds an item,
/// Delete removes the last one. Desktop and web users expect shortcuts, and
/// people using a switch or an external keyboard on a phone rely on them.
class KeyboardList extends StatefulWidget {
  const KeyboardList({super.key});

  @override
  State<KeyboardList> createState() => _KeyboardListState();
}

class _KeyboardListState extends State<KeyboardList> {
  final _items = <String>['First'];

  void _add() => setState(() => _items.add('Item ${_items.length + 1}'));
  void _removeLast() => setState(() {
    if (_items.isNotEmpty) _items.removeLast();
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _add,
        const SingleActivator(LogicalKeyboardKey.delete): _removeLast,
      },
      // Shortcuts only fire while something inside has keyboard focus.
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Semantics(liveRegion: true, child: Text('${_items.length} items')),
            for (final item in _items) ListTile(title: Text(item)),
            TextButton(onPressed: _add, child: const Text('Add (Ctrl+N)')),
          ],
        ),
      ),
    );
  }
}
// #enddocregion keyboard
