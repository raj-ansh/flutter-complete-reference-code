// Chapter 28: how long does heavy work keep the main isolate from running
// anything else? A timer that should fire every 10 ms measures the longest
// gap. In a Flutter app the same gap is a frozen screen.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

String makeJson(int items) => jsonEncode([
  for (var i = 0; i < items; i++)
    {'id': i, 'name': 'item number $i', 'tags': ['a', 'b', 'c'], 'score': i * 0.5},
]);

int parseAndCount(String text) => (jsonDecode(text) as List).length;

/// Runs [work] while a 10 ms ticker records the longest time between ticks.
Future<(int, double)> measure(Future<int> Function() work) async {
  var last = Stopwatch()..start();
  var longestGapMs = 0.0;
  final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
    final gap = last.elapsedMicroseconds / 1000;
    if (gap > longestGapMs) longestGapMs = gap;
    last = Stopwatch()..start();
  });
  await Future<void>.delayed(const Duration(milliseconds: 50)); // settle
  longestGapMs = 0;
  final result = await work();
  await Future<void>.delayed(const Duration(milliseconds: 50));
  timer.cancel();
  return (result, longestGapMs);
}

Future<void> main() async {
  final text = makeJson(150000);
  print('JSON text: ${(text.length / 1e6).toStringAsFixed(1)} MB, 150,000 items');

  final (n1, onMain) = await measure(() async => parseAndCount(text));
  print('parse on the main isolate:   longest gap between 10 ms ticks = '
      '${onMain.toStringAsFixed(0)} ms ($n1 items)');

  final (n2, inIsolate) = await measure(() => Isolate.run(() => parseAndCount(text)));
  print('parse in Isolate.run:        longest gap between 10 ms ticks = '
      '${inIsolate.toStringAsFixed(0)} ms ($n2 items)');
}
