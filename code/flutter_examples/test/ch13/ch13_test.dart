import 'package:flutter/material.dart';
import 'package:flutter_examples/ch13/async_gap.dart';
import 'package:flutter_examples/ch13/dialogs_demo.dart';
import 'package:flutter_examples/ch13/menus_progress.dart';
import 'package:flutter_examples/ch13/sheets_snacks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screenshot.dart';

Widget app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
  home: home,
);

void main() {
  group('dialogs', () {
    testWidgets('confirm: delete, cancel, and dismiss by tapping outside', (
      tester,
    ) async {
      await saveScreenshot(
        tester,
        app(const DialogsPage()),
        'ch13_confirm_dialog',
        size: const Size(360, 480),
        beforeCapture: (t) async {
          await t.tap(find.text('Confirm'));
          await t.pumpAndSettle();
        },
      );

      await tester.pumpWidget(app(const DialogsPage()));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Deleted'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Kept'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // the dim barrier
      await tester.pumpAndSettle();
      expect(find.text('Dismissed without choosing'), findsOneWidget);
    });

    testWidgets('choice and text dialogs return values', (tester) async {
      await tester.pumpWidget(app(const DialogsPage()));

      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cherry'));
      await tester.pumpAndSettle();
      expect(find.text('Fruit: cherry'), findsOneWidget);

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Ada  ');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Ada'), findsOneWidget);
    });

    testWidgets('choice dialog screenshot', (tester) async {
      await saveScreenshot(
        tester,
        app(const DialogsPage()),
        'ch13_choice_dialog',
        size: const Size(360, 480),
        beforeCapture: (t) async {
          await t.tap(find.text('Choose'));
          await t.pumpAndSettle();
        },
      );
    });
  });

  testWidgets('snack bar with undo restores the item', (tester) async {
    await tester.pumpWidget(app(const UndoList()));
    expect(find.text('Water tomatoes'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pump(); // snack bar starts animating in
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Water tomatoes'), findsNothing);
    expect(find.text('Deleted "Water tomatoes"'), findsOneWidget);

    await saveScreenshot(
      tester,
      app(const UndoList()),
      'ch13_snackbar',
      size: const Size(360, 420),
      beforeCapture: (t) async {
        await t.tap(find.byTooltip('Delete').first);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      },
    );

    await tester.pumpWidget(app(const UndoList()));
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Water tomatoes'), findsOneWidget);
  });

  testWidgets('bottom sheet and banner', (tester) async {
    await saveScreenshot(
      tester,
      app(const SheetDemo()),
      'ch13_bottom_sheet',
      size: const Size(360, 480),
      beforeCapture: (t) async {
        await t.tap(find.text('Sort...'));
        await t.pumpAndSettle();
      },
    );

    await tester.pumpWidget(app(const SheetDemo()));
    await tester.tap(find.text('Sort...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('date'));
    await tester.pumpAndSettle();
    expect(find.text('Sorted by date'), findsOneWidget);

    await saveScreenshot(
      tester,
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showOfflineBanner(context),
                child: const Text('Go offline'),
              ),
            ),
          ),
        ),
      ),
      'ch13_banner',
      size: const Size(360, 240),
      beforeCapture: (t) async {
        await t.tap(find.text('Go offline'));
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('popup menu and MenuAnchor', (tester) async {
    await saveScreenshot(
      tester,
      app(const PopupDemo()),
      'ch13_popup_menu',
      size: const Size(360, 320),
      beforeCapture: (t) async {
        await t.tap(find.byType(PopupMenuButton<NoteAction>));
        await t.pumpAndSettle();
      },
    );

    await tester.pumpWidget(app(const PopupDemo()));
    await tester.tap(find.byType(PopupMenuButton<NoteAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Last action: share'), findsOneWidget);

    await saveScreenshot(
      tester,
      app(const MenuAnchorDemo()),
      'ch13_menu_anchor',
      size: const Size(360, 300),
      beforeCapture: (t) async {
        await t.tap(find.text('File'));
        await t.pumpAndSettle();
        await t.tap(find.text('Export'));
        await t.pumpAndSettle();
      },
    );

    await tester.pumpWidget(app(const MenuAnchorDemo()));
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Chose: PDF'), findsOneWidget);
  });

  testWidgets('progress indicators and tooltip', (tester) async {
    await saveScreenshot(
      tester,
      app(const Scaffold(body: ProgressDemo())),
      'ch13_progress',
      size: const Size(360, 360),
      settle: false, // indeterminate indicators animate forever
    );

    await tester.pumpWidget(app(const Scaffold(body: TooltipDemo())));
    await tester.longPress(find.byIcon(Icons.favorite_border));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Add to favorites'), findsOneWidget);
  });

  testWidgets('the safe version checks context.mounted', (tester) async {
    await tester.pumpWidget(
      app(const Scaffold(body: Center(child: SaveButton()))),
    );
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('saved'), findsOneWidget);
  });
}
