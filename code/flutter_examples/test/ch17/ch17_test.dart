import 'package:flutter/material.dart';
import 'package:flutter_examples/ch17/lifting.dart';
import 'package:flutter_examples/ch17/notifier_demos.dart';
import 'package:flutter_examples/ch17/pantry_model.dart';
import 'package:flutter_examples/ch17/provider_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

Widget app(Widget body) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
  home: Scaffold(body: SizedBox.expand(child: body)),
);

void main() {
  setUp(buildCounts.clear);

  testWidgets('lifting state up: the parent owns the count', (tester) async {
    await tester.pumpWidget(app(const LiftedCounterPage()));
    expect(find.text('Items: 0'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Add'));
    }
    await tester.pump();
    expect(find.text('Items: 3'), findsOneWidget);
  });

  testWidgets('ValueListenableBuilder rebuilds only its builder', (
    tester,
  ) async {
    await tester.pumpWidget(app(const TemperaturePanel()));
    expect(find.text('20.0 °C'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Warmer'));
      await tester.pump();
    }
    expect(find.text('21.5 °C'), findsOneWidget);
    writeCaptured(
      'ch17_value_builds.txt',
      'after 3 taps on "Warmer":\n'
          'TemperaturePanel.build ran   ${buildCounts['panel']} time(s)\n'
          'ValueListenableBuilder ran   ${buildCounts['reading']} time(s)',
    );
    expect(buildCounts['panel'], 1);
    expect(buildCounts['reading'], 4); // first build + 3 changes
  });

  testWidgets('ChangeNotifier with ListenableBuilder', (tester) async {
    await tester.pumpWidget(app(const PantryPage()));
    expect(find.text('0 left to buy'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Milk');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Basil');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('2 left to buy'), findsOneWidget);

    await tester.tap(find.text('Milk'));
    await tester.pump();
    expect(find.text('1 left to buy'), findsOneWidget);

    await saveScreenshot(
      tester,
      app(const PantryPage()),
      'ch17_pantry_page',
      size: const Size(360, 320),
      beforeCapture: (t) async {
        for (final name in ['Milk', 'Bread', 'Basil']) {
          await t.enterText(find.byType(TextField), name);
          await t.tap(find.text('Add'));
          await t.pump();
        }
        await t.tap(find.text('Bread'));
        await t.pump();
      },
    );
  });

  testWidgets('forgetting notifyListeners leaves the screen stale', (
    tester,
  ) async {
    final broken = ForgetfulPantryModel();
    addTearDown(broken.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: broken,
          builder: (context, _) => Text('items: ${broken.items.length}'),
        ),
      ),
    );
    broken.add('Milk');
    await tester.pump();
    final stale = find.text('items: 0').evaluate().isNotEmpty;
    final model = PantryModel()..add('Milk');
    addTearDown(model.dispose);
    String? error;
    try {
      model.items.add(const PantryItem('Sneaky'));
    } on Object catch (e) {
      error = '${e.runtimeType}: $e';
    }
    writeCaptured(
      'ch17_model_mistakes.txt',
      'ForgetfulPantryModel.add("Milk") without notifyListeners:\n'
          '  model holds ${broken.items.length} item(s); screen still shows '
          '"${stale ? 'items: 0' : 'updated'}"\n'
          '\n'
          'PantryModel.items.add(...) on the read-only view:\n'
          '  $error',
    );
    expect(stale, isTrue);
    expect(error, isNotNull);
  });

  test('using a disposed notifier is an error', () {
    final model = PantryModel()..dispose();
    String? message;
    try {
      model.add('Milk');
    } on FlutterError catch (e) {
      message = e.toString();
    }
    writeCaptured('ch17_disposed.txt', message ?? 'no error');
    expect(message, contains('disposed'));
  });

  testWidgets('InheritedNotifier rebuilds dependents', (tester) async {
    final model = PantryModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PantryScope(model: model, child: const RemainingText()),
      ),
    );
    expect(find.text('0 left to buy'), findsOneWidget);
    model.add('Milk');
    await tester.pump();
    expect(find.text('1 left to buy'), findsOneWidget);
  });

  testWidgets('provider: watch, select and read rebuild differently', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PantryApp()));
    final rows = StringBuffer()
      ..writeln(
        'build() calls caused by each action (the first row is the start-up build)',
      )
      ..writeln(
        '${'action'.padRight(28)}list  select badge  watch badge  add bar',
      );
    Future<void> record(String label) async {
      rows.writeln(
        label.padRight(28) +
            '${buildCounts['list'] ?? 0}'.padLeft(4) +
            '${buildCounts['select badge'] ?? 0}'.padLeft(14) +
            '${buildCounts['watch badge'] ?? 0}'.padLeft(13) +
            '${buildCounts['add bar'] ?? 0}'.padLeft(10),
      );
      buildCounts.clear();
    }

    await record('start');

    await tester.tap(find.byType(Checkbox).first); // changes remaining 3 -> 2
    await tester.pump();
    await record('tick a checkbox');

    await tester.longPress(find.text('Bread')); // rename: remaining unchanged
    await tester.pump();
    await record('rename an item');

    await tester.tap(find.text('Add eggs')); // remaining 2 -> 3
    await tester.pump();
    await record('add an item');

    writeCaptured('ch17_rebuilds.txt', rows.toString());
    expect(find.text('Renamed'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);

    await saveScreenshot(
      tester,
      app(const PantryApp()),
      'ch17_provider_app',
      size: const Size(360, 400),
    );
  });

  testWidgets('select skips rebuilds that do not change its value', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PantryApp()));
    buildCounts.clear();
    await tester.longPress(find.text('Bread')); // rename
    await tester.pump();
    expect(buildCounts['list'], 1);
    expect(buildCounts['watch badge'], 1);
    expect(buildCounts['select badge'], isNull); // not rebuilt
    expect(buildCounts['add bar'], isNull); // read never subscribes
  });

  testWidgets('context.watch outside build is rejected', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PantryModel(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.watch<PantryModel>(),
              child: const Text('bad'),
            ),
          ),
        ),
      ),
    );
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    await tester.tap(find.text('bad'));
    FlutterError.onError = old;
    final text = errors.isEmpty ? 'no error' : errors.first.exceptionAsString();
    writeCaptured('ch17_watch_in_callback.txt', text);
    expect(errors, isNotEmpty);
  });
}
