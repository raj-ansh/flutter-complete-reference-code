import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

// #docregion config
/// Applies to every test file in this folder (and below). Turns on leak
/// tracking: after each widget test, objects that should have been disposed
/// but were not are reported as failures.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  await testMain();
}
// #enddocregion config
