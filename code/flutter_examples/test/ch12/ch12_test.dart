import 'package:flutter/material.dart';
import 'package:flutter_examples/ch12/grids_slivers.dart';
import 'package:flutter_examples/ch12/lists_demo.dart';
import 'package:flutter_examples/ch12/states_demo.dart';
import 'package:flutter_examples/ch12/tables_demo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

Widget app(Widget body) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
  home: Scaffold(body: body),
);

void main() {
  testWidgets('lazy lists build only what is visible', (tester) async {
    ItemCounters.reset();
    await tester.pumpWidget(app(const EagerList(count: 1000)));
    final eager = (ItemCounters.constructed, ItemCounters.built);

    ItemCounters.reset();
    await tester.pumpWidget(app(const LazyList(count: 1000)));
    final lazy = (ItemCounters.constructed, ItemCounters.built);

    writeCaptured(
      'ch12_lazy_counts.txt',
      'Test screen: 800 x 600 logical pixels, rows 56 pixels tall, 1000 items\n'
          '                    widgets created   widgets built\n'
          'ListView(children)      ${eager.$1.toString().padLeft(5)}            ${eager.$2.toString().padLeft(5)}\n'
          'ListView.builder        ${lazy.$1.toString().padLeft(5)}            ${lazy.$2.toString().padLeft(5)}',
    );
    expect(eager.$1, 1000);
    expect(eager.$2, lessThan(30));
    expect(lazy.$1, lessThan(30));
    expect(lazy.$2, lessThan(30));
  });

  testWidgets('separated list, reorder, expansion screenshots', (tester) async {
    await saveScreenshot(
      tester,
      app(const ContactList()),
      'ch12_contacts',
      size: const Size(360, 400),
    );
    await saveScreenshot(
      tester,
      app(const ExpansionDemo()),
      'ch12_expansion',
      size: const Size(360, 260),
    );
  });

  testWidgets('pull to refresh replaces the items', (tester) async {
    await tester.pumpWidget(app(const RefreshableList()));
    expect(find.text('Version 1 - first'), findsOneWidget);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump(); // start the gesture
    await tester.pump(const Duration(seconds: 1)); // spinner animates
    await tester.pumpAndSettle(); // refresh completes

    expect(find.text('Version 2 - first'), findsOneWidget);
    expect(find.text('Version 1 - first'), findsNothing);
  });

  testWidgets('infinite list loads more near the end', (tester) async {
    await tester.pumpWidget(app(const InfiniteList()));
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    final before = controller.position.maxScrollExtent; // 20 rows of 56 px

    await tester.drag(find.byType(ListView), const Offset(0, -1100));
    await tester.pump(); // the scroll listener starts a load
    await tester.pump(const Duration(milliseconds: 200)); // load completes
    await tester.pumpAndSettle();

    // A second page of 20 rows was added, so the list became longer.
    expect(controller.position.maxScrollExtent, greaterThan(before));
    writeCaptured(
      'ch12_infinite.txt',
      'scrollable extent before: ${before.toStringAsFixed(0)} px (20 rows)\n'
          'after reaching the end:   ${controller.position.maxScrollExtent.toStringAsFixed(0)} px (40 rows)',
    );
  });

  testWidgets('reordering moves an item', (tester) async {
    await tester.pumpWidget(app(const ReorderDemo()));
    final first = tester.getTopLeft(find.text('Plan'));

    // Long press, then drag "Plan" down in small steps, as a finger would.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Plan')),
    );
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final after = tester.getTopLeft(find.text('Plan'));
    expect(after.dy, greaterThan(first.dy));
  });

  testWidgets('grids and slivers', (tester) async {
    await saveScreenshot(
      tester,
      app(const GridsDemo()),
      'ch12_grids',
      size: const Size(360, 640),
    );
    await saveScreenshot(
      tester,
      const MaterialApp(debugShowCheckedModeBanner: false, home: SliverPage()),
      'ch12_slivers_top',
      size: const Size(360, 640),
    );
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await saveScreenshot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SliverPage(controller: controller),
      ),
      'ch12_slivers_scrolled',
      size: const Size(360, 640),
      beforeCapture: (t) async {
        controller.jumpTo(300);
        await t.pump();
      },
    );
  });

  testWidgets('table, sortable data table, page view', (tester) async {
    await saveScreenshot(
      tester,
      app(const Padding(padding: EdgeInsets.all(12), child: TableDemo())),
      'ch12_table',
      size: const Size(360, 260),
    );

    await tester.pumpWidget(app(const SortableTable()));
    List<String> names() => [
      for (final w in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.byType(Text),
        ),
      ))
        if (plants.any((p) => p.name == w.data)) w.data!,
    ];
    expect(names(), ['Basil', 'Fern', 'Tomato', 'Hosta']);
    await tester.tap(find.text('Height (cm)'));
    await tester.pump();
    expect(names(), ['Basil', 'Hosta', 'Fern', 'Tomato']); // ascending by cm
    await tester.tap(find.text('Height (cm)'));
    await tester.pump();
    expect(names(), ['Tomato', 'Fern', 'Hosta', 'Basil']); // descending

    await saveScreenshot(
      tester,
      app(const SortableTable()),
      'ch12_datatable',
      size: const Size(360, 280),
      beforeCapture: (t) async {
        await t.tap(find.text('Height (cm)'));
        await t.pump();
      },
    );

    await saveScreenshot(
      tester,
      app(const PagesDemo()),
      'ch12_pageview',
      size: const Size(360, 240),
    );
  });

  testWidgets('list states: loading, failed, empty, loaded', (tester) async {
    // A spinner animates forever, so the screenshot helper cannot "settle";
    // pump a few frames ourselves for this one.
    await saveScreenshot(
      tester,
      app(const StatesGallery()),
      'ch12_states',
      size: const Size(360, 760),
      settle: false,
    );

    await tester.pumpWidget(app(const StateView(state: Loaded(<String>[]))));
    expect(find.textContaining('Nothing here yet'), findsOneWidget);

    var retried = false;
    await tester.pumpWidget(
      app(
        StateView(
          state: const Failed('Offline'),
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);

    await tester.pumpWidget(app(const StateView(state: Loading())));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
