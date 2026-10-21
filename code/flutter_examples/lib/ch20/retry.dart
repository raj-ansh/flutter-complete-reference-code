import 'dart:math';

import 'failure.dart';

// #docregion retry
/// Runs [action] again after a growing delay while it fails with a
/// retryable failure. [wait] is a parameter so tests need not really wait.
Future<ApiResult<T>> withRetry<T>(
  Future<ApiResult<T>> Function() action, {
  int maxAttempts = 4,
  Duration firstDelay = const Duration(milliseconds: 500),
  Future<void> Function(Duration) wait = _realWait,
  void Function(int attempt, ApiFailure failure, Duration delay)? onRetry,
}) async {
  for (var attempt = 1; ; attempt++) {
    final result = await action();
    if (result is ApiErr<T>) {
      final failure = result.failure;
      if (failure.retryable && attempt < maxAttempts) {
        // 0.5 s, 1 s, 2 s ... doubling each time, capped at 8 s.
        final delay = Duration(
          milliseconds: min(
            8000,
            firstDelay.inMilliseconds * pow(2, attempt - 1).toInt(),
          ),
        );
        onRetry?.call(attempt, failure, delay);
        await wait(delay);
        continue;
      }
    }
    return result;
  }
}

Future<void> _realWait(Duration d) => Future<void>.delayed(d);
// #enddocregion retry
