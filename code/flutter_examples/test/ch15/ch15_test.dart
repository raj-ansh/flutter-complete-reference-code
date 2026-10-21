import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_examples/ch15/drag_drop.dart';
import 'package:flutter_examples/ch15/explicit_demo.dart';
import 'package:flutter_examples/ch15/gestures_demo.dart';
import 'package:flutter_examples/ch15/hero_demo.dart';
import 'package:flutter_examples/ch15/implicit_demo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

Widget app(Widget body) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
  home: Scaffold(body: SizedBox.expand(child: body)),
);

double boxWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('box'))).width;

/// Measures the AnimatedContainer's width at fixed moments of its animation.
Future<List<double>> sampleWidths(WidgetTester tester, Curve curve) async {
  await tester.pumpWidget(app(ImplicitDemo(key: UniqueKey(), curve: curve)));
  await tester.tap(find.text('Toggle'));
  await tester.pump(); // starts the animation at t = 0
  final widths = <double>[boxWidth(tester)];
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    widths.add(boxWidth(tester));
  }
  return widths;
}

void main() {
  testWidgets('gestures: tap, double tap, drag, long press', (tester) async {
    await saveScreenshot(
      tester,
      app(const GestureBox()),
      'ch15_gestures',
      size: const Size(360, 360),
    );

    await tester.pumpWidget(app(const GestureBox()));
    final box = find.text('touch me');
    Color boxColor() {
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    expect(boxColor(), Colors.indigo);
    await tester.tap(box);
    await tester.pump(
      const Duration(milliseconds: 400),
    ); // wait out double-tap timer
    expect(find.text('Last: tap'), findsOneWidget);
    expect(boxColor(), Colors.deepOrange);

    await tester.tap(box);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(box);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Last: double tap'), findsOneWidget);
    await tester.pumpAndSettle(); // the size animation takes 150 ms
    expect(tester.getSize(find.byType(AnimatedContainer)).width, 160);

    final before = tester.getTopLeft(find.byType(AnimatedContainer));
    await tester.drag(box, const Offset(50, 30));
    await tester.pump();
    final after = tester.getTopLeft(find.byType(AnimatedContainer));
    expect(find.text('Last: drag'), findsOneWidget);
    expect(after.dx, greaterThan(before.dx));

    await tester.longPress(box);
    await tester.pump();
    expect(find.text('Last: long press (reset)'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(AnimatedContainer)), before);
  });

  testWidgets('InkWell reports taps and Card clips the ripple', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(RippleCard(onTap: () => taps++)));
    await tester.tap(find.text('Tap for a ripple'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(taps, 1);
  });

  testWidgets('drag and drop', (tester) async {
    await saveScreenshot(
      tester,
      app(const DragDropDemo()),
      'ch15_dragdrop_start',
      size: const Size(360, 340),
    );
    await tester.pumpWidget(app(const DragDropDemo()));
    expect(find.text('The pot is empty'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Basil')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('The pot is empty')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Basil planted'), findsOneWidget);
  });

  testWidgets('implicit animation: width over time, by curve', (tester) async {
    final linear = await sampleWidths(tester, Curves.linear);
    final eased = await sampleWidths(tester, Curves.easeInOut);

    String row(String name, List<double> w) =>
        '${name.padRight(10)}${w.map((v) => v.toStringAsFixed(1).padLeft(8)).join()}';
    writeCaptured(
      'ch15_curve_samples.txt',
      'width of the box, 100 -> 200 over 1000 ms\n'
          'time (ms)         0     250     500     750    1000\n'
          '${row('linear', linear)}\n'
          '${row('easeInOut', eased)}',
    );

    expect(linear.first, 100);
    expect(linear.last, closeTo(200, 0.5));
    expect(linear[2], closeTo(150, 0.5)); // linear: halfway at half time
    expect(eased[1], lessThan(linear[1])); // ease-in-out starts slowly
    expect(eased[3], greaterThan(linear[3])); // and finishes quickly

    await saveScreenshot(
      tester,
      app(const ImplicitDemo(curve: Curves.linear)),
      'ch15_implicit_mid',
      size: const Size(360, 340),
      settle: false,
      beforeCapture: (t) async {
        await t.tap(find.text('Toggle'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('AnimatedSwitcher and TweenAnimationBuilder', (tester) async {
    await tester.pumpWidget(app(const SwitcherDemo()));
    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-transition both the old and the new child exist.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('0'), findsNothing);

    double angle(WidgetTester t) => t
        .widget<Transform>(
          find.descendant(
            of: find.byType(SpinningStar),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .getRotation()
        .entry(1, 0);
    await tester.pumpWidget(app(const SpinningStar(turns: 0)));
    await tester.pumpWidget(app(const SpinningStar(turns: 0.25)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(angle(tester), closeTo(1, 0.01)); // sin(90 degrees) = 1
  });

  testWidgets('explicit animations are driven by a controller', (tester) async {
    await tester.pumpWidget(app(const PulsingHeart()));
    final state = tester.state<PulsingHeartState>(find.byType(PulsingHeart));
    final seen = <String>[];
    for (var i = 0; i <= 4; i++) {
      seen.add(state.scale.value.toStringAsFixed(2));
      await tester.pump(const Duration(milliseconds: 400));
    }
    writeCaptured(
      'ch15_pulse.txt',
      'scale of the heart every 400 ms (800 ms per direction, reversing):\n'
          '${seen.join(', ')}',
    );
    expect(state.controller.isAnimating, isTrue);
    expect(double.parse(seen.first), 1.0);
    expect(
      double.parse(seen[2]),
      closeTo(1.4, 0.01),
    ); // top of the pulse after 800 ms

    await tester.pumpWidget(app(const FadeSlideIn()));
    final fade = tester.state<FadeSlideInState>(find.byType(FadeSlideIn));
    expect(fade.controller.value, 0);
    await tester.tap(find.text('Play'));
    await tester.pump(); // the first frame starts the animation clock
    await tester.pump(const Duration(milliseconds: 300));
    expect(fade.controller.value, closeTo(0.5, 0.01));
    await tester.pumpAndSettle();
    expect(fade.controller.status, AnimationStatus.completed);

    await saveScreenshot(
      tester,
      app(const FadeSlideIn()),
      'ch15_fadeslide_mid',
      size: const Size(360, 300),
      settle: false,
      beforeCapture: (t) async {
        await t.tap(find.text('Play'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 200));
      },
    );
  });

  testWidgets('staggered intervals start one after another', (tester) async {
    await tester.pumpWidget(app(const StaggeredBars()));
    final state = tester.state<StaggeredBarsState>(find.byType(StaggeredBars));
    state.controller.forward();
    await tester.pump(); // t = 0
    await tester.pump(const Duration(milliseconds: 225)); // 25% of 900 ms
    final atQuarter = [for (final b in state.bars) b.value];
    await tester.pump(const Duration(milliseconds: 225)); // 50%
    final atHalf = [for (final b in state.bars) b.value];
    writeCaptured(
      'ch15_stagger.txt',
      'bar progress (0 to 1)       bar1   bar2   bar3\n'
          'at 25% of the timeline   ${atQuarter.map((v) => v.toStringAsFixed(2).padLeft(6)).join(' ')}\n'
          'at 50% of the timeline   ${atHalf.map((v) => v.toStringAsFixed(2).padLeft(6)).join(' ')}',
    );
    expect(atQuarter[2], 0); // the third bar has not begun
    expect(atQuarter[0], greaterThan(atQuarter[1]));
    expect(atHalf[0], closeTo(1, 0.001)); // the first bar is already done

    await tester.pumpAndSettle();
    expect([for (final b in state.bars) b.value], everyElement(1.0));

    await saveScreenshot(
      tester,
      app(const StaggeredBars()),
      'ch15_stagger_mid',
      size: const Size(360, 280),
      settle: false,
      beforeCapture: (t) async {
        t
            .state<StaggeredBarsState>(find.byType(StaggeredBars))
            .controller
            .forward();
        await t.pump();
        await t.pump(const Duration(milliseconds: 360)); // 40%
      },
    );
  });

  testWidgets('a Hero is present on both screens', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HeroList()));
    expect(find.byType(Hero), findsNWidgets(2)); // one per list row
    await tester.tap(find.text('Basil'));
    await tester.pump(); // flight begins
    await tester.pump(const Duration(milliseconds: 100)); // in flight
    await tester.pumpAndSettle();
    expect(find.byType(Hero), findsOneWidget); // only the detail's hero remains
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(
      tester.getSize(find.byType(CircleAvatar)).width,
      closeTo(120, 0.1),
    ); // it ended at the detail screen's size, radius 60
  });
}
