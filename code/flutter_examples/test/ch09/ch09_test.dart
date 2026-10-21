import 'package:flutter/material.dart';
import 'package:flutter_examples/ch09/box.dart';
import 'package:flutter_examples/ch09/constraints_demo.dart';
import 'package:flutter_examples/ch09/errors_demo.dart';
import 'package:flutter_examples/ch09/flex_demo.dart';
import 'package:flutter_examples/ch09/more_layouts.dart';
import 'package:flutter_examples/ch09/responsive_demo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

String describeSize(Size s) =>
    '${s.width.toStringAsFixed(1)} x ${s.height.toStringAsFixed(1)}';

/// Collects every exception the framework reported during the last frame.
List<String> takeAllExceptions(WidgetTester tester) {
  final messages = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    messages.add(e.toString());
  }
  return messages;
}

/// Pumps [widget] while collecting the errors the framework reports,
/// instead of letting the test fail on them.
Future<List<FlutterErrorDetails>> pumpCollecting(
  WidgetTester tester,
  Widget widget,
) async {
  final errors = <FlutterErrorDetails>[];
  final original = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await tester.pumpWidget(widget);
  } finally {
    FlutterError.onError = original;
  }
  return errors;
}

void main() {
  testWidgets('constraints: tight versus loose', (tester) async {
    await saveScreenshot(
      tester,
      const DemoFrame(
        title: 'Same 60 x 60 request, three parents',
        child: ConstraintsDemo(),
      ),
      'ch09_constraints',
      size: const Size(360, 260),
    );

    final reds = find.byWidgetPredicate(
      (w) => w is Container && w.color == Colors.red,
    );
    final sizes = [for (var i = 0; i < 3; i++) tester.getSize(reds.at(i))];
    writeCaptured(
      'ch09_constraints_trace.txt',
      'A (tight parent):       ${describeSize(sizes[0])}\n'
          'B (loose, sized child): ${describeSize(sizes[1])}\n'
          'C (loose, no size):     ${describeSize(sizes[2])}',
    );
    expect(sizes[0], const Size(110, 150));
    expect(sizes[1], const Size(60, 60));
    expect(sizes[2], const Size(110, 150));
  });

  testWidgets('main axis and cross axis alignment', (tester) async {
    await saveScreenshot(
      tester,
      const DemoFrame(title: 'MainAxisAlignment', child: MainAxisDemo()),
      'ch09_main_axis',
      size: const Size(360, 400),
    );
    await saveScreenshot(
      tester,
      const DemoFrame(title: 'CrossAxisAlignment', child: CrossAxisDemo()),
      'ch09_cross_axis',
      size: const Size(360, 440),
    );
  });

  testWidgets('flex: dividing leftover space', (tester) async {
    await saveScreenshot(
      tester,
      const DemoFrame(child: FlexDemo()),
      'ch09_flex',
      size: const Size(360, 260),
    );
    final boxes = find.byType(Box);
    final w = [for (var i = 0; i < 6; i++) tester.getSize(boxes.at(i)).width];
    writeCaptured(
      'ch09_flex_trace.txt',
      'Row 1 (320 wide): fixed=${w[0]}  flex1=${w[1].toStringAsFixed(1)}  '
          'flex2=${w[2].toStringAsFixed(1)}\n'
          'Row 2 (320 wide): Flexible=${w[3]}  Expanded=${w[4]}',
    );
    expect(w[0], 80);
    expect(w[1], closeTo(80, 0.01)); // (320 - 80) * 1/3
    expect(w[2], closeTo(160, 0.01)); // (320 - 80) * 2/3
    expect(w[3], 60);
    // Each gets half of the 320 free pixels. The Flexible child uses only 60 of
    // its 160; the leftover 100 is NOT handed to the Expanded child.
    expect(w[4], 160);
  });

  testWidgets('overflow: the error message and the fixes', (tester) async {
    await saveScreenshot(
      tester,
      const DemoFrame(child: OverflowBug()),
      'ch09_overflow',
      size: const Size(360, 120),
      beforeCapture: (t) async {
        final messages = takeAllExceptions(t);
        expect(messages, isNotEmpty);
        writeCaptured('ch09_overflow_error.txt', messages.first);
      },
    );
    await saveScreenshot(
      tester,
      const DemoFrame(child: OverflowFixes()),
      'ch09_overflow_fixes',
      size: const Size(360, 300),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unbounded constraints: ListView and TextField', (tester) async {
    final listErrors = await pumpCollecting(
      tester,
      const DemoFrame(child: UnboundedListBug()),
    );
    expect(listErrors, isNotEmpty);
    writeCaptured(
      'ch09_unbounded_list_error.txt',
      listErrors.first.exception.toString(),
    );

    final fixed = await pumpCollecting(
      tester,
      const DemoFrame(child: BoundedListFix()),
    );
    expect(fixed, isEmpty);

    final fieldErrors = await pumpCollecting(
      tester,
      const DemoFrame(child: UnboundedTextFieldBug()),
    );
    expect(fieldErrors, isNotEmpty);
    writeCaptured(
      'ch09_unbounded_textfield_error.txt',
      fieldErrors.first.exception.toString(),
    );

    final fixedField = await pumpCollecting(
      tester,
      const DemoFrame(child: BoundedTextFieldFix()),
    );
    expect(fixedField, isEmpty);
  });

  testWidgets('stack, container, sizing, wrap screenshots', (tester) async {
    await saveScreenshot(
      tester,
      const DemoFrame(child: StackDemo()),
      'ch09_stack',
      size: const Size(340, 240),
    );
    await saveScreenshot(
      tester,
      const DemoFrame(child: ContainerDemo()),
      'ch09_container',
      size: const Size(340, 140),
    );
    await saveScreenshot(
      tester,
      const DemoFrame(child: SizingDemo()),
      'ch09_sizing',
      size: const Size(360, 400),
    );
    await saveScreenshot(
      tester,
      const DemoFrame(child: WrapDemo()),
      'ch09_wrap',
      size: const Size(360, 130),
    );
  });

  testWidgets('responsive layout and SafeArea', (tester) async {
    await saveScreenshot(
      tester,
      const DemoFrame(child: ResponsiveDemo()),
      'ch09_responsive_narrow',
      size: const Size(360, 360),
    );
    await saveScreenshot(
      tester,
      const DemoFrame(child: ResponsiveDemo()),
      'ch09_responsive_wide',
      size: const Size(800, 240),
    );
    await saveScreenshot(
      tester,
      const SafeAreaDemo(safe: false),
      'ch09_safearea_off',
      size: const Size(360, 400),
    );
    await saveScreenshot(
      tester,
      const SafeAreaDemo(safe: true),
      'ch09_safearea_on',
      size: const Size(360, 400),
    );
  });
}
