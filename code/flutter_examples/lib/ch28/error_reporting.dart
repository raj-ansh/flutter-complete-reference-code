import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// #docregion reporter
/// Where problems end up. In a real app this would write to a log file or send
/// to a crash-reporting service (Chapter 29: never include secrets). Here it
/// just collects descriptions, so the tests can look at them.
class ErrorReporter {
  final reports = <String>[];

  void report(String kind, Object error, StackTrace? stack) {
    final firstLine = '$error'.split('\n').first;
    reports.add('$kind: $firstLine');
  }
}
// #enddocregion reporter

// #docregion install
/// Installs handlers for the three places an error can come from:
///  1. errors Flutter catches itself (build, layout, painting, gestures),
///  2. errors that escape asynchronous code anywhere in the app,
///  3. a friendly replacement for the red error screen in release builds.
/// Returns a function that puts the old handlers back (for tests).
VoidCallback installErrorHandling(ErrorReporter reporter) {
  final oldFlutterHandler = FlutterError.onError;
  final oldPlatformHandler = PlatformDispatcher.instance.onError;
  final oldBuilder = ErrorWidget.builder;

  FlutterError.onError = (details) {
    reporter.report('flutter', details.exception, details.stack);
    // In debug builds also print as usual, so developers see the details.
    if (kDebugMode) FlutterError.presentError(details);
  };

  // Returning true tells the engine the error has been handled.
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report('async', error, stack);
    return true;
  };

  ErrorWidget.builder = (details) => const Material(
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Something went wrong on this screen.'),
      ),
    ),
  );

  return () {
    FlutterError.onError = oldFlutterHandler;
    PlatformDispatcher.instance.onError = oldPlatformHandler;
    ErrorWidget.builder = oldBuilder;
  };
}
// #enddocregion install

// #docregion zone
/// The older, still useful way to catch everything: run the app in a zone
/// that has an error handler. It also catches errors from code started before
/// the Flutter binding exists.
void runGuarded(void Function() body, ErrorReporter reporter) {
  runZonedGuarded(
    body,
    (error, stack) => reporter.report('zone', error, stack),
  );
}
// #enddocregion zone

/// A widget with a bug in its build method, for the tests.
class BrokenWidget extends StatelessWidget {
  const BrokenWidget({super.key});

  @override
  Widget build(BuildContext context) {
    throw StateError('this widget cannot be built');
  }
}
