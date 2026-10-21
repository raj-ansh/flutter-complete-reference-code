import 'package:flutter/widgets.dart';

/// How many times each child's build method has run.
final Map<String, int> buildCounts = {};

// #docregion child
class CountedChild extends StatelessWidget {
  const CountedChild({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    buildCounts[name] = (buildCounts[name] ?? 0) + 1;
    return Text(name);
  }
}
// #enddocregion child

// #docregion parent
class CounterParent extends StatefulWidget {
  const CounterParent({super.key});

  @override
  State<CounterParent> createState() => CounterParentState();
}

class CounterParentState extends State<CounterParent> {
  int count = 0;

  void increment() => setState(() => count++);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Text('count: $count'),
          const CountedChild(name: 'const child'), // one shared instance
          CountedChild(name: 'plain child'), // a new instance every build
        ],
      ),
    );
  }
}
// #enddocregion parent
