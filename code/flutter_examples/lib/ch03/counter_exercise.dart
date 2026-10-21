import 'package:flutter/material.dart';

void main() => runApp(const CounterExerciseApp());

class CounterExerciseApp extends StatelessWidget {
  const CounterExerciseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CounterExercisePage());
  }
}

class CounterExercisePage extends StatefulWidget {
  const CounterExercisePage({super.key});

  @override
  State<CounterExercisePage> createState() => _CounterExercisePageState();
}

class _CounterExercisePageState extends State<CounterExercisePage> {
  int _counter = 0;

  void _change(int delta) {
    setState(() {
      _counter += delta;
    });
  }

  void _reset() {
    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter with decrement and reset')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$_counter', style: Theme.of(context).textTheme.displayMedium),
            Text(_counter.isEven ? 'even' : 'odd'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Decrement',
                  icon: const Icon(Icons.remove),
                  onPressed: () => _change(-1),
                ),
                IconButton(
                  tooltip: 'Increment',
                  icon: const Icon(Icons.add),
                  onPressed: () => _change(1),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
