import 'package:flutter/material.dart';

import 'box.dart';

// #docregion stack
/// Overlapping children with Stack, Positioned and Align.
class StackDemo extends StatelessWidget {
  const StackDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 200,
      child: Stack(
        children: [
          // Fills the whole stack.
          Positioned.fill(child: Container(color: Colors.teal.shade100)),
          // Pinned to the top-left corner with an offset.
          const Positioned(
            left: 12,
            top: 12,
            child: Box('top-left', width: 80, height: 30),
          ),
          // Stretched between two edges.
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            height: 30,
            child: Container(color: Colors.deepOrange.withValues(alpha: 0.8)),
          ),
          // Placed by Align: the center of the stack.
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.star, size: 48, color: Colors.amber),
          ),
          // A badge on the top-right corner.
          const Positioned(
            right: 8,
            top: 8,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Text('3', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
// #enddocregion stack

// #docregion container
/// Container combines padding, margin, size, alignment and decoration.
class ContainerDemo extends StatelessWidget {
  const ContainerDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.all(8), // space outside the border
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF26A69A), Color(0xFF80CBC4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade900, width: 2),
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(2, 4), color: Colors.black38),
        ],
      ),
      child: const Text(
        'Padding inside, margin outside',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
// #enddocregion container

// #docregion sizing
/// Widgets that influence size.
class SizingDemo extends StatelessWidget {
  const SizingDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Text('ConstrainedBox(minWidth: 200)'),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: const Box('at least 200', height: 30),
          ),
          const SizedBox(height: 10),
          const Text('FractionallySizedBox(widthFactor: 0.5)'),
          FractionallySizedBox(
            widthFactor: 0.5,
            alignment: Alignment.centerLeft,
            child: const Box('half', height: 30, color: Colors.teal),
          ),
          const SizedBox(height: 10),
          const Text('AspectRatio(16 / 9) at 160 wide'),
          SizedBox(
            width: 160,
            child: const AspectRatio(
              aspectRatio: 16 / 9,
              child: Box('16:9', color: Colors.deepOrange),
            ),
          ),
          const SizedBox(height: 10),
          const Text('FittedBox scales its child down to fit 120 x 30'),
          SizedBox(
            width: 120,
            height: 30,
            child: FittedBox(
              child: Text(
                'This is much too long for the space',
                style: TextStyle(color: Colors.indigo.shade900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// #enddocregion sizing

// #docregion wrap
/// Wrap flows its children onto new lines.
class WrapDemo extends StatelessWidget {
  const WrapDemo({super.key});

  static const tags = [
    'Dart',
    'Flutter',
    'Widgets',
    'Layout',
    'State',
    'Routing',
    'Testing',
    'Animation',
    'Packages',
    'Release',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [for (final tag in tags) Chip(label: Text(tag))],
    );
  }
}
// #enddocregion wrap
