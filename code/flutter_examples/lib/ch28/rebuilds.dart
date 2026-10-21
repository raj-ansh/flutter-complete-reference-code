import 'package:flutter/material.dart';

// #docregion rebuilds
/// A panel that is "expensive" only in the sense that we want to see whether
/// Flutter asks it to build again.
class Panel extends StatelessWidget {
  const Panel(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) => Text('panel $name');
}

/// Version 1: the counter lives in the screen's own State, so every tap calls
/// setState on the whole screen. The Panels are created again in each build
/// (they are not const), so each one rebuilds.
class WholeScreenCounter extends StatefulWidget {
  const WholeScreenCounter({super.key});

  @override
  State<WholeScreenCounter> createState() => _WholeScreenCounterState();
}

class _WholeScreenCounterState extends State<WholeScreenCounter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => setState(() => _count++),
          child: Text('count $_count'),
        ),
        Panel('A'), // a new object on every build
        Panel('B'),
      ],
    );
  }
}

/// Version 2: only the button has state. Its setState rebuilds the button and
/// nothing else; the const Panels are never asked to build again.
class SplitCounter extends StatelessWidget {
  const SplitCounter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CounterButton(),
        Panel('A'), // const: the very same object every time
        Panel('B'),
      ],
    );
  }
}

class CounterButton extends StatefulWidget {
  const CounterButton({super.key});

  @override
  State<CounterButton> createState() => _CounterButtonState();
}

class _CounterButtonState extends State<CounterButton> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('count $_count'),
    );
  }
}
// #enddocregion rebuilds
