import 'package:flutter/material.dart';
import 'package:flutter_examples/ch31/contrast.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';

void main() {
  // #docregion known
  test('the two extremes and a known grey', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.001));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1.0, 0.001));
    // #767676 on white is the classic "just passes AA" grey: about 4.54:1.
    expect(
      contrastRatio(const Color(0xFF767676), Colors.white),
      closeTo(4.54, 0.01),
    );
  });
  // #enddocregion known

  test('order of the two colors does not matter', () {
    const a = Color(0xFF1B5E20);
    expect(contrastRatio(a, Colors.white), contrastRatio(Colors.white, a));
  });

  test('report the generated color schemes', () {
    final buffer = StringBuffer();
    for (final seed in [Colors.teal, Colors.deepPurple, Colors.amber]) {
      for (final brightness in Brightness.values) {
        final scheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
        );
        final failing = failingPairs(scheme);
        buffer.writeln(
          'seed ${seed.toARGB32().toRadixString(16)} ${brightness.name}: '
          '${pairsOf(scheme).length - failing.length} of ${pairsOf(scheme).length} pairs reach 4.5:1',
        );
        for (final (pair, ratio) in failing) {
          buffer.writeln('    ${pair.name}: ${ratio.toStringAsFixed(2)}');
        }
      }
    }
    writeCaptured('ch31_scheme_contrast.txt', buffer.toString());
  });
}
