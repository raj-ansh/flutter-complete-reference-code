import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_examples/ch01/hello_flutter.dart';

import '../support/screenshot.dart';

void main() {
  testWidgets('screenshot of the Hello app', (tester) async {
    await saveScreenshot(
      tester,
      const HelloApp(),
      'ch01_hello',
      size: const Size(360, 240),
    );
  });
}
