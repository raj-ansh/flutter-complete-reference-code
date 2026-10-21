import 'package:flutter/material.dart';

// #docregion lifted
/// State lifted to the nearest common ancestor: both children need the count,
/// so the parent owns it and passes data down and callbacks up.
class LiftedCounterPage extends StatefulWidget {
  const LiftedCounterPage({super.key});

  @override
  State<LiftedCounterPage> createState() => _LiftedCounterPageState();
}

class _LiftedCounterPageState extends State<LiftedCounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CountLabel(count: _count), // data flows down
        AddButton(onPressed: () => setState(() => _count++)), // events flow up
      ],
    );
  }
}

class CountLabel extends StatelessWidget {
  const CountLabel({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Text('Items: $count');
}

class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: onPressed, child: const Text('Add'));
}
// #enddocregion lifted
