import 'package:flutter/material.dart';
import 'package:flutter_examples/ch27/leaky.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a field that disposes its controller is clean', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TidyField())),
    );
    await tester.pumpWidget(const SizedBox()); // remove it, so it is disposed
  });
}
