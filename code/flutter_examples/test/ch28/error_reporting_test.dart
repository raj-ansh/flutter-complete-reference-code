import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_examples/ch28/error_reporting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';

void main() {
  // #docregion widgettest
  testWidgets('a bug in build is reported and replaced by a friendly widget', (
    tester,
  ) async {
    final reporter = ErrorReporter();
    // The test framework insists that FlutterError.onError is back to normal
    // when the test body ends, so restore inside the body, not in a tear-down.
    final restore = installErrorHandling(reporter);
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: BrokenWidget())),
        ),
      );

      expect(
        reporter.reports.single,
        'flutter: Bad state: this widget cannot be built',
      );
      expect(find.text('Something went wrong on this screen.'), findsOneWidget);
      writeCaptured(
        'ch28_error_widget.txt',
        'reporter received:  ${reporter.reports.single}\n'
            'screen shows:       "Something went wrong on this screen." (instead of the red error screen)',
      );
    } finally {
      restore();
    }
  });
  // #enddocregion widgettest

  test(
    'an error that escapes asynchronous code reaches the zone handler',
    () async {
      final reporter = ErrorReporter();
      final done = Completer<void>();
      runGuarded(() {
        Future<void>.delayed(Duration.zero, () {
          throw FormatException('nobody caught this');
        });
        Future<void>.delayed(const Duration(milliseconds: 20), done.complete);
      }, reporter);
      await done.future;
      expect(reporter.reports, ['zone: FormatException: nobody caught this']);
    },
  );

  test('without any handler the same error would be unhandled', () async {
    // Shown for contrast: an error thrown in a Future nobody awaits is only
    // seen by the zone. This test catches it with a local zone to prove it.
    final seen = <Object>[];
    final done = Completer<void>();
    runZonedGuarded(() {
      Future<void>.error(StateError('lost'));
      Future<void>.delayed(const Duration(milliseconds: 10), done.complete);
    }, (e, s) => seen.add(e));
    await done.future;
    expect(seen.single, isA<StateError>());
  });
}
