import 'dart:isolate';

// #docregion work
// Deliberately slow, CPU-bound work: count the primes below a limit.
int countPrimes(int limit) {
  var count = 0;
  for (var n = 2; n < limit; n++) {
    var isPrime = true;
    for (var d = 2; d * d <= n; d++) {
      if (n % d == 0) {
        isPrime = false;
        break;
      }
    }
    if (isPrime) count++;
  }
  return count;
}
// #enddocregion work

// #docregion run
Future<void> main() async {
  // Isolate.run starts a separate isolate, runs the function there, and
  // returns its result. The isolate has its own memory, so the main
  // isolate stays free to handle events while the work runs.
  var count = await Isolate.run(() => countPrimes(200000));
  print('primes below 200000: $count');

  // Errors thrown in the isolate are re-thrown here.
  try {
    await Isolate.run(() => throw StateError('failed in isolate'));
  } on StateError catch (e) {
    print('caught: ${e.message}');
  }
}
// #enddocregion run
