import 'package:flutter/material.dart';
import 'package:flutter_examples/ch08/context_demo.dart';
import 'package:flutter_examples/ch08/inherited_demo.dart';
import 'package:flutter_examples/ch08/keys_demo.dart';
import 'package:flutter_examples/ch08/lifecycle_demo.dart';
import 'package:flutter_examples/ch08/rebuild_count.dart';
import 'package:flutter_examples/ch08/three_trees.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';

/// Runs [dump] while collecting everything it prints through debugPrint.
String collect(void Function() dump) {
  final lines = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
  try {
    dump();
  } finally {
    debugPrint = original;
  }
  return lines.join('\n');
}

void main() {
  testWidgets('the widget tree and the render tree of TinyApp', (tester) async {
    await tester.pumpWidget(const TinyApp());

    writeCaptured('ch08_dump_app.txt', collect(debugDumpApp));
    writeCaptured('ch08_dump_render.txt', collect(debugDumpRenderTree));

    expect(find.text('Hi'), findsOneWidget);
  });

  testWidgets('lifecycle order', (tester) async {
    final log = <String>[];

    await tester.pumpWidget(LifecycleProbe(label: 'A', log: log));
    log.add('--- tap ---');
    await tester.tap(find.text('A: 0'));
    await tester.pump();
    log.add('--- parent supplies a new widget: label B ---');
    await tester.pumpWidget(LifecycleProbe(label: 'B', log: log));
    log.add('--- widget removed from the tree ---');
    await tester.pumpWidget(const SizedBox());

    writeCaptured('ch08_lifecycle_log.txt', log.join('\n'));
    expect(log.first, 'initState');
    expect(log.last, 'dispose');
  });

  testWidgets('const children are not rebuilt', (tester) async {
    buildCounts.clear();
    await tester.pumpWidget(const CounterParent());
    final state = tester.state<CounterParentState>(find.byType(CounterParent));

    for (var i = 0; i < 3; i++) {
      state.increment();
      await tester.pump();
    }

    writeCaptured(
      'ch08_rebuild_counts.txt',
      'after 3 increments (4 builds of the parent):\n'
          '  const child built ${buildCounts['const child']} time(s)\n'
          '  plain child built ${buildCounts['plain child']} time(s)',
    );
    expect(buildCounts['const child'], 1);
    expect(buildCounts['plain child'], 4);
    expect(find.text('count: 3'), findsOneWidget);
  });

  testWidgets('without keys, state stays with the position', (tester) async {
    await tester.pumpWidget(const SwapDemo(useKeys: false));
    await tester.tap(find.text('A:0')); // tap tile A once
    await tester.pump();
    expect(find.text('A:1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('swap')));
    await tester.pump();

    // The first tile is now labelled B but kept the old tap count: a bug.
    expect(find.text('B:1'), findsOneWidget);
    expect(find.text('A:0'), findsOneWidget);
  });

  testWidgets('with keys, state follows its tile', (tester) async {
    await tester.pumpWidget(const SwapDemo(useKeys: true));
    await tester.tap(find.text('A:0'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('swap')));
    await tester.pump();

    expect(find.text('A:1'), findsOneWidget);
    expect(find.text('B:0'), findsOneWidget);
  });

  testWidgets('using the wrong BuildContext fails; Builder fixes it', (
    tester,
  ) async {
    await tester.pumpWidget(const WrongContext());
    await tester.tap(find.text('Go'));
    await tester.pump();
    final error = tester.takeException();
    expect(error, isNotNull);
    final message = error.toString();
    writeCaptured('ch08_context_error.txt', message);

    await tester.pumpWidget(const RightContext());
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('an InheritedWidget rebuilds only dependents that care', (
    tester,
  ) async {
    colorLabelBuilds = 0;
    Widget app(Color color) => Directionality(
      textDirection: TextDirection.ltr,
      child: ColorScope(color: color, child: const ColorLabel()),
    );

    await tester.pumpWidget(app(const Color(0xFFFF0000)));
    expect(colorLabelBuilds, 1);
    expect(find.text('color: ffff0000'), findsOneWidget);

    await tester.pumpWidget(app(const Color(0xFFFF0000))); // same color
    expect(colorLabelBuilds, 1);

    await tester.pumpWidget(app(const Color(0xFF0000FF))); // new color
    expect(colorLabelBuilds, 2);
    expect(find.text('color: ff0000ff'), findsOneWidget);
  });
}
