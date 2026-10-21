import 'dart:async';

// #docregion fetch
// A function that takes time returns a Future.
Future<String> fetchName(int id) async {
  await Future.delayed(const Duration(milliseconds: 100));
  if (id < 0) throw ArgumentError('id must not be negative');
  return 'user-$id';
}
// #enddocregion fetch

// #docregion run
Future<void> main() async {
  // await pauses THIS function (not the whole program) until the Future completes.
  var name = await fetchName(1);
  print('got $name');

  // Errors from a Future are thrown at the await, so try/catch works.
  try {
    await fetchName(-1);
  } on ArgumentError catch (e) {
    print('failed: ${e.message}');
  } finally {
    print('cleanup runs either way');
  }

  // The older callback style does the same job.
  fetchName(2).then((n) => print('then: $n')).catchError((Object e) {
    print('never printed');
  });
  await Future.delayed(const Duration(milliseconds: 150));

  // Sequential versus parallel.
  var sw = Stopwatch()..start();
  await fetchName(1);
  await fetchName(2);
  await fetchName(3);
  var sequential = sw.elapsedMilliseconds;

  sw
    ..reset()
    ..start();
  var names = await Future.wait([fetchName(1), fetchName(2), fetchName(3)]);
  var parallel = sw.elapsedMilliseconds;

  print(names);
  print('sequential took at least 300 ms: ${sequential >= 300}');
  print('parallel was faster: ${parallel < sequential}');

  // Timeouts.
  try {
    await fetchName(5).timeout(const Duration(milliseconds: 10));
  } on TimeoutException {
    print('timed out');
  }

  // A Future that is already complete.
  var ready = await Future.value(42);
  print(ready);
}
// #enddocregion run
