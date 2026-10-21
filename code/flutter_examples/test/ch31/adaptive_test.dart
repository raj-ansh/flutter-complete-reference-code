import 'package:flutter/material.dart';
import 'package:flutter_examples/ch31/adaptive.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';

void main() {
  // #docregion sizes
  Future<void> showAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdaptiveShell()));
  }

  testWidgets('a phone-width window gets a bottom bar', (tester) async {
    await showAt(tester, const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a tablet-width window gets a rail', (tester) async {
    await showAt(tester, const Size(900, 700));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('the breakpoint itself counts as wide', (tester) async {
    await showAt(tester, const Size(600, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('selection survives a change of layout', (tester) async {
    await showAt(tester, const Size(400, 800));
    await tester.tap(find.text('Tasks'));
    await tester.pump();
    expect(find.text('Tasks page'), findsOneWidget);

    // As if the window was resized: the same widget, a different width.
    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Tasks page'), findsOneWidget);
  });
  // #enddocregion sizes

  // #docregion textscale
  Future<Object?> pumpWithTextScale(
    WidgetTester tester,
    Widget row,
    double scale,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: row),
      ),
    );
    return tester.takeException();
  }

  testWidgets('the fragile row overflows at 2x text, the robust row does not', (
    tester,
  ) async {
    final fragile = await pumpWithTextScale(tester, const FragileRow(), 2);
    final robust = await pumpWithTextScale(tester, const RobustRow(), 2);

    writeCaptured(
      'ch31_textscale.txt',
      'FragileRow at 2x: ${fragile.toString().split('\n').first}\n'
          'RobustRow at 2x:  ${robust ?? 'no exception'}',
    );
    expect(fragile, isNotNull);
    expect(robust, isNull);
  });
  // #enddocregion textscale
}
