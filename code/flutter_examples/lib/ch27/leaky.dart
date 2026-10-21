import 'package:flutter/material.dart';

// #docregion leaky
/// A widget with a deliberate bug: it creates a controller and never disposes
/// it. Leak tracking in the test framework should notice.
class LeakyField extends StatefulWidget {
  const LeakyField({super.key});

  @override
  State<LeakyField> createState() => _LeakyFieldState();
}

class _LeakyFieldState extends State<LeakyField> {
  final _controller = TextEditingController();

  // The bug: there is no dispose() that calls _controller.dispose().

  @override
  Widget build(BuildContext context) => TextField(controller: _controller);
}

/// The fixed version.
class TidyField extends StatefulWidget {
  const TidyField({super.key});

  @override
  State<TidyField> createState() => _TidyFieldState();
}

class _TidyFieldState extends State<TidyField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: _controller);
}
// #enddocregion leaky
