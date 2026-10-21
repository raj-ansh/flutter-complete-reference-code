import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_organizer/features/notes/note.dart';

import '../../support/fakes.dart';
import '../../support/fakes_more.dart';
import '../../support/screenshot.dart';

final t0 = DateTime.utc(2026, 10, 16, 9);

Note note(String title, String body, {int minutes = 0, bool pinned = false}) =>
    Note(
      title: title,
      body: body,
      pinned: pinned,
      updatedAt: t0.add(Duration(minutes: minutes)),
    );

Widget appWith(FakeNotesRepository repo, {String initialLocation = '/'}) =>
    TestApp(
      notes: repo,
      now: t0.add(const Duration(days: 1)),
    ).widget(initialLocation: initialLocation);

FakeNotesRepository seeded() => FakeNotesRepository([
  note('Shopping', 'Milk, eggs, basil', minutes: 5),
  note('Garden plan', 'Repot the fern before winter', minutes: 3, pinned: true),
  note('Ideas', 'A book about Flutter', minutes: 1),
]);

void main() {
  testWidgets('an empty app invites you to write a note', (tester) async {
    await tester.pumpWidget(appWith(FakeNotesRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('Tap + to write your first note.'), findsOneWidget);
  });

  testWidgets('create a note through the screens', (tester) async {
    final repo = FakeNotesRepository();
    await tester.pumpWidget(appWith(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    expect(find.text('New note'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Milk');
    await tester.enterText(
      find.widgetWithText(TextField, 'Write something…'),
      'two litres',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(AppBar, 'Notes'),
      findsOneWidget,
    ); // back on the list
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('two litres'), findsOneWidget);
  });

  testWidgets('open a note, change it, and save', (tester) async {
    await tester.pumpWidget(appWith(seeded()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ideas'));
    await tester.pumpAndSettle();
    expect(find.text('Edit note'), findsOneWidget);
    expect(find.text('A book about Flutter'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Book ideas',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Book ideas'), findsOneWidget);
    expect(find.text('Ideas'), findsNothing);
  });

  testWidgets('pinned notes come first, and pinning moves a note', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(seeded()));
    await tester.pumpAndSettle();
    List<String> order() => tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data!)
        .toList();
    expect(order(), ['Garden plan', 'Shopping', 'Ideas']);

    await tester.tap(find.byTooltip('Pin').first); // Shopping's pin button
    await tester.pumpAndSettle();
    expect(order().first, 'Shopping');
  });

  testWidgets('search narrows the list and explains an empty result', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(seeded()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'fern');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Garden plan'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches'), findsOneWidget);
  });

  testWidgets('swipe to delete, then Undo brings it back', (tester) async {
    await tester.pumpWidget(appWith(seeded()));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Ideas'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Ideas'), findsNothing);
    expect(find.text('Deleted "Ideas"'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Ideas'), findsOneWidget);
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    await tester.pumpWidget(appWith(FakeNotesRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();

    // Nothing typed: back leaves at once.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Notes'), findsOneWidget);

    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Draft');
    await tester.pump(); // let the listener's setState rebuild PopScope
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('New note'), findsOneWidget); // still editing

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Notes'), findsOneWidget);
    expect(find.text('Draft'), findsNothing);
  });

  testWidgets('a failed save keeps the editor open with a message', (
    tester,
  ) async {
    final repo = FakeNotesRepository();
    await tester.pumpWidget(appWith(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Precious');
    repo.failing = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('The storage is unavailable'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget); // the user's text is safe
    expect(find.text('Precious'), findsOneWidget);
  });

  testWidgets('a broken store shows an error with Try again', (tester) async {
    final repo = seeded()..failing = true;
    await tester.pumpWidget(appWith(repo));
    await tester.pumpAndSettle();
    expect(find.text('The storage is unavailable'), findsOneWidget);

    repo.failing = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Shopping'), findsOneWidget);
  });

  testWidgets('a link to a missing note says so instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(FakeNotesRepository(), initialLocation: '/notes/999'),
    );
    await tester.pumpAndSettle();
    expect(find.text('This note no longer exists.'), findsOneWidget);
  });

  testWidgets('screens for the book', (tester) async {
    await saveScreenshot(
      tester,
      appWith(seeded()),
      'po_ch22_list',
      size: const Size(360, 520),
    );
    await saveScreenshot(
      tester,
      appWith(FakeNotesRepository()),
      'po_ch22_empty',
      size: const Size(360, 400),
    );
    await saveScreenshot(
      tester,
      appWith(seeded(), initialLocation: '/notes/new'),
      'po_ch22_edit',
      size: const Size(360, 400),
      beforeCapture: (t) async {
        await t.enterText(
          find.widgetWithText(TextField, 'Title'),
          'Weekend plan',
        );
        await t.enterText(
          find.widgetWithText(TextField, 'Write something…'),
          'Repot the fern.\nBuy basil seeds.\nCall Sam about Saturday.',
        );
        await t.pump();
      },
    );
    await saveScreenshot(
      tester,
      appWith(seeded()),
      'po_ch22_undo',
      size: const Size(360, 420),
      beforeCapture: (t) async {
        await t.drag(find.text('Ideas'), const Offset(-600, 0));
        await t.pumpAndSettle();
      },
    );
  });
}
