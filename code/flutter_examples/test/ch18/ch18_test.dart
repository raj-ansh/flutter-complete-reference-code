import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_examples/ch17/pantry_model.dart';
import 'package:flutter_examples/ch18/copy_with.dart';
import 'package:flutter_examples/ch18/data.dart';
import 'package:flutter_examples/ch18/vm_bloc.dart';
import 'package:flutter_examples/ch18/vm_notifier.dart';
import 'package:flutter_examples/ch18/vm_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as p;

import '../support/capture.dart';
import '../support/screenshot.dart';

const _start = [PantryItem('Milk'), PantryItem('Bread')];

InMemoryPantryService makeService() => InMemoryPantryService(initial: _start);

Widget host(Widget body) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
  home: Scaffold(body: body),
);

/// The three ways of driving the same view, each given the same repository.
final implementations = <String, Widget Function(PantryRepository)>{
  'ChangeNotifier + provider': (repo) => p.Provider<PantryRepository>.value(
    value: repo,
    child: host(const NotifierPantryScreen()),
  ),
  'Riverpod': (repo) => ProviderScope(
    // Riverpod 3 retries failed providers by default; switch that off so the
    // test controls the timing.
    retry: (_, _) => null,
    overrides: [pantryRepositoryProvider.overrideWithValue(repo)],
    child: host(const RiverpodPantryScreen()),
  ),
  'Bloc': (repo) => RepositoryProvider<PantryRepository>.value(
    value: repo,
    child: host(const BlocPantryScreen()),
  ),
};

const wait = Duration(milliseconds: 120);

/// Counts non-blank, non-comment lines in a named region of a source file.
int regionLines(String path, String region) {
  final lines = File(path).readAsLinesSync();
  final start = lines.indexWhere((l) => l.contains('#docregion $region'));
  final end = lines.indexWhere((l) => l.contains('#enddocregion $region'));
  return lines
      .sublist(start + 1, end)
      .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('//'))
      .length;
}

void main() {
  group('repository (no Flutter widgets involved)', () {
    test('caches, refreshes and reports failures as values', () async {
      final service = makeService();
      final repo = PantryRepository(service);

      final first = await repo.load();
      await repo.load();
      final afterTwoLoads = service.fetchCount;
      await repo.load(refresh: true);
      final afterRefresh = service.fetchCount;

      final added = await repo.add('Eggs');
      service.failing = true;
      final failedSave = await repo.toggle(0);
      service.failing = false;
      final stillThere = await repo.load();

      final fresh = PantryRepository(service);
      service.failing = true;
      final failedLoad = await fresh.load();
      final tooEarly = await PantryRepository(makeService()).toggle(0);

      String describe(Result<List<PantryItem>> r) => switch (r) {
        Ok(:final value) => 'Ok(${value.map((i) => i.name).join(', ')})',
        Err(:final message) => 'Err("$message")',
      };
      writeCaptured(
        'ch18_repository.txt',
        'load() twice, service fetches:      $afterTwoLoads\n'
            'load(refresh: true), fetches:       $afterRefresh\n'
            'first load:                         ${describe(first)}\n'
            'add("Eggs"):                        ${describe(added)}\n'
            'toggle(0) while service is down:    ${describe(failedSave)}\n'
            'load() afterwards (cache intact):   ${describe(stillThere)}\n'
            'load() on a fresh repo, service down: ${describe(failedLoad)}\n'
            'toggle(0) before any load:          ${describe(tooEarly)}',
      );
      expect(afterTwoLoads, 1);
      expect(afterRefresh, 2);
      expect(failedSave, isA<Err<List<PantryItem>>>());
      expect(
        (stillThere as Ok<List<PantryItem>>).value.map((i) => i.name),
        ['Milk', 'Bread', 'Eggs'],
      );
      expect(failedLoad, isA<Err<List<PantryItem>>>());
    });
  });

  group('copyWith and null', () {
    test('the simple version cannot clear a field', () {
      final r = Reminder(title: 'Call', due: DateTime(2026, 12, 1));
      final simple = r.copyWithSimple(due: null);
      final wrapped = r.copyWith(due: () => null);
      final kept = r.copyWith(title: 'Call Sam');
      final named = r.withoutDue();
      writeCaptured(
        'ch18_copywith.txt',
        'start:                      due = ${r.due}\n'
            'copyWithSimple(due: null):  due = ${simple.due}\n'
            'copyWith(due: () => null):  due = ${wrapped.due}\n'
            'copyWith(title: "..."):     due = ${kept.due}\n'
            'withoutDue():               due = ${named.due}',
      );
      expect(simple.due, isNotNull);
      expect(wrapped.due, isNull);
      expect(kept.due, r.due);
      expect(named.due, isNull);
    });
  });

  for (final entry in implementations.entries) {
    group(entry.key, () {
      testWidgets('loading, then the list, then a toggle', (tester) async {
        final repo = PantryRepository(makeService());
        await tester.pumpWidget(entry.value(repo));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(wait);
        expect(find.text('Milk'), findsOneWidget);
        expect(find.text('Bread'), findsOneWidget);

        await tester.tap(find.text('Milk'));
        await tester.pump(wait);
        final milk = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Milk'),
        );
        expect(milk.value, isTrue);

        await tester.tap(find.text('Add eggs'));
        await tester.pump(wait);
        expect(find.text('Eggs'), findsOneWidget);
      });

      testWidgets('a failed load shows an error and Retry recovers', (
        tester,
      ) async {
        final service = makeService()..failing = true;
        await tester.pumpWidget(entry.value(PantryRepository(service)));
        await tester.pump(wait);
        expect(find.textContaining('Could not load'), findsOneWidget);

        service.failing = false;
        await tester.tap(find.text('Retry'));
        await tester.pump(); // loading state is shown
        await tester.pump(wait);
        expect(find.text('Milk'), findsOneWidget);
      });

      testWidgets('a failed action keeps the list and reports the problem', (
        tester,
      ) async {
        final service = makeService();
        await tester.pumpWidget(entry.value(PantryRepository(service)));
        await tester.pump(wait);
        service.failing = true;
        await tester.tap(find.text('Milk'));
        await tester.pump(wait);
        expect(find.text('Milk'), findsOneWidget); // still on screen
        expect(find.textContaining('Could not save'), findsOneWidget);
        final milk = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Milk'),
        );
        expect(milk.value, isFalse); // the change was not applied
      });
    });
  }

  testWidgets('closing the screen while loading is safe', (tester) async {
    await tester.pumpWidget(
      implementations['ChangeNotifier + provider']!(
        PantryRepository(makeService()),
      ),
    );
    await tester.pumpWidget(const SizedBox()); // leave before data arrives
    await tester.pump(wait);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screens for the book', (tester) async {
    await saveScreenshot(
      tester,
      implementations['ChangeNotifier + provider']!(
        PantryRepository(makeService()),
      ),
      'ch18_loaded',
      size: const Size(360, 300),
      settle: false,
      beforeCapture: (t) async => t.pump(wait),
    );
    final down = makeService()..failing = true;
    await saveScreenshot(
      tester,
      implementations['ChangeNotifier + provider']!(PantryRepository(down)),
      'ch18_failed',
      size: const Size(360, 200),
      settle: false,
      beforeCapture: (t) async => t.pump(wait),
    );
  });

  test('size of the three view-model implementations', () {
    final rows = <String, int>{
      'ChangeNotifier + provider':
          regionLines('lib/ch18/vm_notifier.dart', 'viewmodel') +
          regionLines('lib/ch18/vm_notifier.dart', 'screen'),
      'Riverpod':
          regionLines('lib/ch18/vm_riverpod.dart', 'providers') +
          regionLines('lib/ch18/vm_riverpod.dart', 'screen'),
      'Bloc':
          regionLines('lib/ch18/vm_bloc.dart', 'bloc') +
          regionLines('lib/ch18/vm_bloc.dart', 'screen'),
    };
    final buffer = StringBuffer(
      'non-blank, non-comment lines of the book listings (state-to-view\n'
      'mapping included, shared PantryState/PantryView/repository excluded)\n',
    );
    rows.forEach((k, v) => buffer.writeln('${k.padRight(28)}$v'));
    writeCaptured('ch18_sizes.txt', buffer.toString());
    expect(rows.values.every((v) => v > 0), isTrue);
  });
}
