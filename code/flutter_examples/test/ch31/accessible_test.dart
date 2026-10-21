import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_examples/ch31/accessible.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  // #docregion guidelines
  testWidgets('the careless button fails the tap-target and label guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(CarelessLikeButton(onTap: () {})));

    final target = await androidTapTargetGuideline.evaluate(tester);
    final label = await labeledTapTargetGuideline.evaluate(tester);
    writeCaptured(
      'ch31_guidelines_careless.txt',
      'androidTapTargetGuideline: passed=${target.passed}\n${target.reason}\n\n'
          'labeledTapTargetGuideline: passed=${label.passed}\n${label.reason}',
    );

    expect(target.passed, isFalse);
    expect(label.passed, isFalse);
    handle.dispose();
  });

  testWidgets('the repaired button passes both', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(LikeButton(liked: false, onChanged: (_) {})));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
  // #enddocregion guidelines

  // #docregion semantics
  testWidgets(
    'the rating bar tells a screen reader its label, value and actions',
    (tester) async {
      final handle = tester.ensureSemantics();
      var value = 3;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => RatingBar(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('Rating'));
      writeCaptured('ch31_rating_semantics.txt', node.toString());
      expect(node.value, '3 of 5');
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );

      // What the screen reader's "swipe up" does:
      tester.semantics.increase(find.semantics.byLabel('Rating'));
      await tester.pump();
      expect(value, 4);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Rating')).value,
        '4 of 5',
      );
      handle.dispose();
    },
  );
  // #enddocregion semantics
}
