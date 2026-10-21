import 'package:flutter/material.dart';

import 'box.dart';

// #docregion overflow
/// Three 150-pixel boxes in a 320-pixel space: 130 pixels too wide.
class OverflowBug extends StatelessWidget {
  const OverflowBug({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Row(
        children: const [
          Box('1', width: 150, height: 40),
          Box('2', width: 150, height: 40, color: Colors.teal),
          Box('3', width: 150, height: 40, color: Colors.deepOrange),
        ],
      ),
    );
  }
}
// #enddocregion overflow

// #docregion overflowfix
/// Three fixes for the same problem, each shown in a 320-pixel space.
class OverflowFixes extends StatelessWidget {
  const OverflowFixes({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text('1. Expanded: share the space'),
          Row(
            children: const [
              Expanded(child: Box('1', height: 40)),
              Expanded(child: Box('2', height: 40, color: Colors.teal)),
              Expanded(child: Box('3', height: 40, color: Colors.deepOrange)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('2. Wrap: continue on the next line'),
          const Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              Box('1', width: 150, height: 40),
              Box('2', width: 150, height: 40, color: Colors.teal),
              Box('3', width: 150, height: 40, color: Colors.deepOrange),
            ],
          ),
          const SizedBox(height: 12),
          const Text('3. Scroll: let the row scroll sideways'),
          SingleChildScrollView(
            scrollDirection: .horizontal,
            child: Row(
              children: const [
                Box('1', width: 150, height: 40),
                Box('2', width: 150, height: 40, color: Colors.teal),
                Box('3', width: 150, height: 40, color: Colors.deepOrange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// #enddocregion overflowfix

// #docregion unbounded
/// A scrolling list inside a Column has no height limit to work with.
class UnboundedListBug extends StatelessWidget {
  const UnboundedListBug({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Title'),
        ListView(children: const [Text('one'), Text('two')]),
      ],
    );
  }
}

/// The fix: give the list the space left over after the other children.
class BoundedListFix extends StatelessWidget {
  const BoundedListFix({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Title'),
        Expanded(child: ListView(children: const [Text('one'), Text('two')])),
      ],
    );
  }
}
// #enddocregion unbounded

// #docregion textfield
/// A TextField inside a Row has no width limit to work with.
class UnboundedTextFieldBug extends StatelessWidget {
  const UnboundedTextFieldBug({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: const [Text('Name:'), TextField()]);
  }
}

/// The fix: let the field take the remaining width.
class BoundedTextFieldFix extends StatelessWidget {
  const BoundedTextFieldFix({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Text('Name: '),
        Expanded(child: TextField()),
      ],
    );
  }
}
// #enddocregion textfield
