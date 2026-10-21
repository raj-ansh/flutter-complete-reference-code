import 'package:flutter/material.dart';

// #docregion scorecard
/// A small widget used to demonstrate golden (image comparison) tests.
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.title, required this.score});

  final String title;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Score: $score'),
          ],
        ),
      ),
    );
  }
}
// #enddocregion scorecard
