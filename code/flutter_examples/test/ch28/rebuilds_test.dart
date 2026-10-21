import 'package:flutter/material.dart';
import 'package:flutter_examples/ch28/rebuilds.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';

/// Runs [action] with Flutter's own rebuild logging switched on and returns the
/// names of the widgets that were rebuilt.
Future<List<String>> rebuiltDuring(Future<void> Function() action) async {
  final lines = <String>[];
  final oldPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) lines.add(message);
  };
  debugPrintRebuildDirtyWidgets = true;
  try {
    await action();
  } finally {
    debugPrintRebuildDirtyWidgets = false;
    debugPrint = oldPrint;
  }
  // Lines look like "Rebuilding Panel-[<...>](...)" or "Building Text".
  return [
    for (final line in lines)
      if (line.startsWith('Rebuilding ') || line.startsWith('Building '))
        line.split(' ')[1].split(RegExp(r'[-(\[]')).first,
  ];
}

void main() {
  testWidgets('setState high in the tree rebuilds the panels; splitting avoids it', (
    tester,
  ) async {
    Future<List<String>> tapAndCollect(Widget app) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: app)));
      return rebuiltDuring(() async {
        await tester.tap(find.byType(TextButton));
        await tester.pump();
      });
    }

    final whole = await tapAndCollect(const WholeScreenCounter());
    final split = await tapAndCollect(const SplitCounter());
    // Each Panel rebuilds as a "Panel", and its Text child as "Text".
    int count(List<String> names, String name) =>
        names.where((n) => n == name).length;

    String col(Object v) => v.toString().padLeft(9);
    writeCaptured(
      'ch28_rebuilds.txt',
      [
        'one tap on the counter button, counted with debugPrintRebuildDirtyWidgets',
        '',
        '                                           version 1   version 2',
        '                                           (whole      (state only',
        '                                           screen)     in button)',
        'widgets rebuilt in total                 ${col(whole.length)}   ${col(split.length)}',
        'of which Panel                           ${col(count(whole, 'Panel'))}   ${col(count(split, 'Panel'))}',
        'of which the stateful widget itself      ${col(count(whole, 'WholeScreenCounter'))}   ${col(count(split, 'CounterButton'))}',
      ].join('\n'),
    );
    expect(count(whole, 'Panel'), 2);
    expect(count(split, 'Panel'), 0);
    expect(split.length, lessThan(whole.length));
  });
}
