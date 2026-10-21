import 'package:flutter/material.dart';

import 'box.dart';

// #docregion panels
/// Three ways a child can receive constraints from the same 110 x 150 parent.
class ConstraintsDemo extends StatelessWidget {
  const ConstraintsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceAround,
      children: [
        _Panel(
          title: 'A',
          // A SizedBox gives its child TIGHT constraints: exactly 110 x 150.
          // The Container's own 60 x 60 request is ignored.
          child: Container(width: 60, height: 60, color: Colors.red),
        ),
        _Panel(
          title: 'B',
          // Center passes LOOSE constraints: anything from 0 x 0 up to 110 x 150.
          // Now the 60 x 60 request is honoured.
          child: Center(
            child: Container(width: 60, height: 60, color: Colors.red),
          ),
        ),
        _Panel(
          title: 'C',
          // Loose constraints, but no size and no child: a Container with
          // nothing to wrap expands to the largest size allowed.
          child: Center(child: Container(color: Colors.red)),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        Text(title),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(border: Border.all()),
          child: SizedBox(width: 110, height: 150, child: child),
        ),
      ],
    );
  }
}
// #enddocregion panels

/// The same panels without screenshots chrome, used for the layout trace.
Widget constraintsDemoApp() => const DemoFrame(child: ConstraintsDemo());
