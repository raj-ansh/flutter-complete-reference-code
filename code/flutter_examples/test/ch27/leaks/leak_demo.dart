// A deliberately failing test, kept out of the normal suite (its name does not
// end in _test.dart). Run it on purpose to see the leak report:
//   flutter test test/ch27/leaks/leak_demo.dart
import 'package:flutter/material.dart';
import 'package:flutter_examples/ch27/leaky.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a field that forgets to dispose its controller leaks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LeakyField())),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
