import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_examples/ch03/counter_app.dart';
import 'package:flutter_examples/ch03/counter_exercise.dart';
import 'package:flutter_examples/ch03/counter_missing_setstate.dart';

void main() {
  // #docregion smoke
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
  // #enddocregion smoke

  testWidgets('Without setState the screen keeps showing 0', (tester) async {
    await tester.pumpWidget(const BrokenCounter());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // The internal value is now 1, but nothing told Flutter to rebuild.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('Exercise: decrement, increment and reset work', (tester) async {
    await tester.pumpWidget(const CounterExerciseApp());
    expect(find.text('0'), findsOneWidget);
    expect(find.text('even'), findsOneWidget);

    await tester.tap(find.byTooltip('Increment'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('odd'), findsOneWidget);

    await tester.tap(find.byTooltip('Decrement'));
    await tester.tap(find.byTooltip('Decrement'));
    await tester.pump();
    expect(find.text('-1'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });
}
