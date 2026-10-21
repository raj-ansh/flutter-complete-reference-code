import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_organizer/core/database.dart';
import 'package:pocket_organizer/core/result.dart';
import 'package:pocket_organizer/features/notes/note.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/capture.dart';
import 'support/fakes.dart';
import 'support/fakes_more.dart';
import 'support/screenshot.dart';

Future<List<String>> schemaSql(Database db) async =>
    (await db.rawQuery(
      'SELECT name, sql FROM sqlite_master '
      "WHERE type IN ('table','index') AND name NOT LIKE 'sqlite_%' "
      'ORDER BY name',
    )).map((r) {
      final sql = (r['sql'] as String).replaceAll(RegExp(r'\s+'), ' ');
      return '${r['name']}: $sql';
    }).toList();

Future<List<Object?>> tableNames(Database db) async => (await db.rawQuery(
  "SELECT name FROM sqlite_master WHERE type='table' "
  "AND name NOT LIKE 'sqlite_%' ORDER BY name",
)).map((r) => r['name']).toList();

void main() {
  sqfliteFfiInit();

  group('schema versions', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('schema_'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // best effort
      }
    });

    test(
      'upgrading a version 1 file keeps its notes and matches a fresh install',
      () async {
        final path = p.join(dir.path, 'old.db');
        // A phone that installed the Chapter 22 release: schema version 1.
        final v1 = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, v) async {
              await db.execute('''
              CREATE TABLE notes(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                pinned INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL
              )''');
              await db.execute(
                'CREATE INDEX idx_notes_updated ON notes(updated_at)',
              );
            },
          ),
        );
        await v1.insert(
          'notes',
          Note(
            title: 'Written in version 1',
            body: 'precious',
            updatedAt: DateTime.utc(2026, 10, 1),
          ).toMap()..remove('id'),
        );
        final before = await tableNames(v1);
        await v1.close();

        final upgraded = await openOrganizerDatabase(databaseFactoryFfi, path);
        final fresh = await openOrganizerDatabase(
          databaseFactoryFfi,
          p.join(dir.path, 'fresh.db'),
        );
        final after = await tableNames(upgraded);
        final notes = await upgraded.query('notes');
        final tasks = await upgraded.query('tasks');
        final upgradedSql = await schemaSql(upgraded);
        final freshSql = await schemaSql(fresh);
        final version = await upgraded.getVersion();
        await upgraded.close();
        await fresh.close();

        writeCaptured(
          'po_ch23_migration.txt',
          'tables in the version 1 file:        $before\n'
              'tables after opening (version $version):  $after\n'
              'the old note:                       "${notes.single['title']}"\n'
              'rows in the new tasks table:        ${tasks.length}\n'
              'upgraded schema equals a fresh install: '
              '${upgradedSql.join('|') == freshSql.join('|')}',
        );
        expect(version, organizerSchemaVersion);
        expect(notes.single['title'], 'Written in version 1');
        expect(tasks, isEmpty);
        expect(upgradedSql, freshSql);
      },
    );
  });

  group('the tab shell', () {
    testWidgets('each tab keeps its place when you leave and return', (
      tester,
    ) async {
      final t = TestApp(
        notes: FakeNotesRepository([
          Note(
            title: 'Fern care',
            body: 'water weekly',
            updatedAt: DateTime.utc(2026, 10, 1),
          ),
          Note(
            title: 'Shopping',
            body: 'milk',
            updatedAt: DateTime.utc(2026, 10, 2),
          ),
        ]),
      );
      await tester.pumpWidget(t.widget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'fern');
      await tester.pumpAndSettle();
      expect(find.text('Shopping'), findsNothing);

      await tester.tap(find.text('Tasks')); // the tab label
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Tasks'), findsOneWidget);

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      // The same search is still applied: the branch was kept alive.
      expect(find.text('Fern care'), findsOneWidget);
      expect(find.text('Shopping'), findsNothing);
    });

    testWidgets('editors cover the tab bar; saving returns to the same tab', (
      tester,
    ) async {
      final t = TestApp();
      await tester.pumpWidget(t.widget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byTooltip('New contact'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing); // full-screen editor

      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Contacts'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
    });

    testWidgets('one pass through all four features', (tester) async {
      final t = TestApp();
      await tester.pumpWidget(t.widget());
      await tester.pumpAndSettle();

      // A note.
      await tester.tap(find.byTooltip('New note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Trip');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // A task.
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Task'), 'Pack');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // An appointment.
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New appointment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Flight');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // A contact.
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New contact'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(((await t.notes.list()) as Ok<List<Note>>).value, hasLength(1));
      expect(t.tasks.items.length, 1);
      expect(t.appointments.items.length, 1);
      expect(t.contacts.items.length, 1);
    });

    testWidgets('screens for the book', (tester) async {
      await saveScreenshot(
        tester,
        TestApp(
          notes: FakeNotesRepository([
            Note(
              title: 'Garden plan',
              body: 'Repot the fern before winter',
              updatedAt: DateTime.utc(2026, 10, 2),
            ),
          ]),
        ).widget(),
        'po_ch23_home',
        size: const Size(360, 420),
      );
    });
  });
}
