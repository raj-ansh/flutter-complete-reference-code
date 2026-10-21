import 'package:flutter/material.dart';

/// A deliberately broken counter: the value changes, the screen does not.
class BrokenCounter extends StatefulWidget {
  const BrokenCounter({super.key});

  @override
  State<BrokenCounter> createState() => _BrokenCounterState();
}

class _BrokenCounterState extends State<BrokenCounter> {
  int _counter = 0;

  // #docregion broken
  void _incrementCounter() {
    _counter++; // The value changes, but Flutter is never told.
  }
  // #enddocregion broken

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('$_counter')),
        floatingActionButton: FloatingActionButton(
          onPressed: _incrementCounter,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
