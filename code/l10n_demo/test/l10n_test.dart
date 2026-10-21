import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_demo/l10n/app_localizations.dart';
import 'package:l10n_demo/task_page.dart';

void main() {
  // #docregion plurals
  Future<String> countText(
    WidgetTester tester,
    String language,
    int count,
  ) async {
    await tester.pumpWidget(TaskApp(locale: Locale(language), count: count));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(TaskPage)));
    return l10n.taskCount(count);
  }

  testWidgets('plural forms: English, Spanish, Arabic', (tester) async {
    final report = StringBuffer();
    for (final language in ['en', 'es', 'ar']) {
      for (final n in [0, 1, 2, 3, 11, 100]) {
        report.writeln(
          '$language  $n -> ${await countText(tester, language, n)}',
        );
      }
    }
    File('../captured/ch31_plurals.txt').writeAsStringSync(report.toString());

    expect(await countText(tester, 'en', 1), 'One task');
    expect(await countText(tester, 'en', 5), '5 tasks');
    expect(await countText(tester, 'es', 1), 'Una tarea');
  });
  // #enddocregion plurals

  // #docregion dates
  testWidgets('the same date is formatted by locale', (tester) async {
    final report = StringBuffer();
    for (final language in ['en', 'es', 'ar']) {
      await tester.pumpWidget(TaskApp(locale: Locale(language)));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(TaskPage)));
      report.writeln('$language: ${l10n.dueOn(DateTime(2026, 10, 21))}');
    }
    File('../captured/ch31_dates.txt').writeAsStringSync(report.toString());
    expect(report.toString(), contains('Oct 21, 2026'));
  });
  // #enddocregion dates

  // #docregion rtl
  testWidgets('Arabic lays the screen out right to left', (tester) async {
    Future<(TextDirection, double)> measure(String language) async {
      await tester.pumpWidget(TaskApp(locale: Locale(language)));
      await tester.pumpAndSettle();
      final direction = Directionality.of(
        tester.element(find.byType(TaskPage)),
      );
      final leftEdge = tester.getTopLeft(find.byType(FilledButton)).dx;
      return (direction, leftEdge);
    }

    final (enDirection, enLeft) = await measure('en');
    final (arDirection, arLeft) = await measure('ar');

    expect(enDirection, TextDirection.ltr);
    expect(arDirection, TextDirection.rtl);
    // The button hugs the left margin in English and the right one in Arabic.
    expect(enLeft, 16);
    expect(arLeft, greaterThan(300));
  });
  // #enddocregion rtl

  testWidgets('every language provides every message', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(TaskApp(locale: locale));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(TaskPage)));
      expect(l10n.appTitle, isNotEmpty);
      expect(l10n.addTask, isNotEmpty);
    }
  });
}
