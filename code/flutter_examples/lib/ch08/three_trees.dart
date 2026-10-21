import 'package:flutter/widgets.dart';

// #docregion tiny
/// The smallest useful tree. It uses only the widgets library (no Material),
/// so the debug dump of its trees stays short enough to read.
class TinyApp extends StatelessWidget {
  const TinyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Hi')),
    );
  }
}
// #enddocregion tiny
