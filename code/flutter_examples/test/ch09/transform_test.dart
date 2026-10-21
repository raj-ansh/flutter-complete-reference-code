import 'package:flutter/material.dart';
import 'package:flutter_examples/ch09/transform_demo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';

void main() {
  testWidgets('what each wrapper does to the space a child takes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TransformGallery()))),
    );

    Size sizeOf(String key) => tester.getSize(find.byKey(Key(key)));
    final report = [
      'Each widget wraps the same 100 x 40 box.',
      '',
      'Transform.rotate(angle: 0.5)   layout size ${sizeOf('transform')}',
      'RotatedBox(quarterTurns: 1)    layout size ${sizeOf('rotated')}',
      'Opacity(opacity: 0.5)          layout size ${sizeOf('opacity')}',
      'ClipRRect(radius 20)           layout size ${sizeOf('clip')}',
    ].join(String.fromCharCode(10));
    writeCaptured('ch09_transform_sizes.txt', report);

    expect(sizeOf('transform'), const Size(100, 40));
    expect(sizeOf('rotated'), const Size(40, 100));
    expect(sizeOf('opacity'), const Size(100, 40));
    expect(sizeOf('clip'), const Size(100, 40));
  });
}
