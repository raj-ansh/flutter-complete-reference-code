import 'package:flutter/material.dart';

import 'box.dart';

// #docregion mainaxis
/// Every MainAxisAlignment value, each in a 320-wide row of three boxes.
class MainAxisDemo extends StatelessWidget {
  const MainAxisDemo({super.key});

  static const values = <MainAxisAlignment>[
    .start,
    .center,
    .end,
    .spaceBetween,
    .spaceAround,
    .spaceEvenly,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        for (final value in values) ...[
          Text(value.name, style: const TextStyle(fontSize: 12)),
          Container(
            width: 320,
            color: Colors.black12,
            child: Row(
              mainAxisAlignment: value,
              children: const [
                Box('1', width: 50, height: 30),
                Box('2', width: 50, height: 30),
                Box('3', width: 50, height: 30),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
// #enddocregion mainaxis

// #docregion crossaxis
/// Every CrossAxisAlignment value, each in a row 70 pixels tall.
class CrossAxisDemo extends StatelessWidget {
  const CrossAxisDemo({super.key});

  static const values = <CrossAxisAlignment>[.start, .center, .end, .stretch];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        for (final value in values) ...[
          Text(value.name, style: const TextStyle(fontSize: 12)),
          Container(
            width: 320,
            height: 70,
            color: Colors.black12,
            child: Row(
              crossAxisAlignment: value,
              children: const [
                Box('S', width: 50, height: 20),
                Box('M', width: 50, height: 40, color: Colors.teal),
                Box('L', width: 50, height: 60, color: Colors.deepOrange),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
// #enddocregion crossaxis

// #docregion flex
/// Dividing leftover space among children.
class FlexDemo extends StatelessWidget {
  const FlexDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text('fixed 80 + Expanded(flex 1) + Expanded(flex 2)'),
          SizedBox(
            height: 40,
            child: Row(
              children: const [
                Box('80', width: 80),
                Expanded(flex: 1, child: Box('1', color: Colors.teal)),
                Expanded(flex: 2, child: Box('2', color: Colors.deepOrange)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Flexible and Expanded (flex 1 each): equal shares'),
          SizedBox(
            height: 40,
            child: Row(
              children: const [
                Flexible(child: Box('loose', width: 60, color: Colors.teal)),
                Expanded(child: Box('fills', color: Colors.deepOrange)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Spacer pushes siblings apart'),
          SizedBox(
            height: 40,
            child: Row(
              children: const [
                Box('left', width: 60),
                Spacer(),
                Box('right', width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// #enddocregion flex
