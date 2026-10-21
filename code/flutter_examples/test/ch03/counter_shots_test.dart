import 'package:flutter/material.dart';
import 'package:flutter_examples/ch03/counter_app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screenshot.dart';

void main() {
  testWidgets('screenshot: counter at start', (tester) async {
    await saveScreenshot(tester, const MyApp(), 'ch03_counter_start');
  });

  testWidgets('screenshot: counter after three taps', (tester) async {
    await saveScreenshot(
      tester,
      const MyApp(),
      'ch03_counter_after',
      beforeCapture: (tester) async {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byIcon(Icons.add));
          await tester.pump();
        }
      },
    );
  });
}
