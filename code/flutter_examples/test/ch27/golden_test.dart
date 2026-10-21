import 'package:flutter/material.dart';
import 'package:flutter_examples/ch27/score_card.dart';
import 'package:flutter_test/flutter_test.dart';

// #docregion golden
void main() {
  testWidgets('the score card looks the way it did when the golden was made', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: ScoreCard(title: 'Skyline Courier', score: 42)),
        ),
      ),
    );
    await expectLater(
      find.byType(ScoreCard),
      matchesGoldenFile('goldens/score_card.png'),
    );
  });
}
// #enddocregion golden
