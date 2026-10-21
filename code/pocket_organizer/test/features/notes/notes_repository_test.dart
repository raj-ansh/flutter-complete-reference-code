import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_organizer/core/database.dart';
import 'package:pocket_organizer/core/result.dart';
import 'package:pocket_organizer/features/notes/note.dart';
import 'package:pocket_organizer/features/notes/notes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/capture.dart';
import '../../support/fakes.dart';

/// The same behavior is demanded of every NotesRepository.
void contract(String name, Future<NotesRepository> Function() create) {
  group('NotesRepository contract: $name', () {
    final t0 = DateTime.utc(2026, 10, 16, 9);
    late NotesRepository repo;

    Future<Note> add(
      String title,
      String body, {
      int minutes = 0,
      bool pinned = false,
    }) async {
      final result = await repo.save(
        Note(
          title: title,
          body: body,
          pinned: pinned,
          updatedAt: t0.add(Duration(minutes: minutes)),
        ),
      );
      return (result as Ok<Note>).value;
    }

    Future<List<String>> titles({String query = ''}) async =>
        ((await repo.list(query: query)) as Ok<List<Note>>).value
            .map((n) => n.title)
            .toList();

    setUp(() async => repo = await create());

    test('assigns ids and lists pinned first, then newest first', () async {
      final a = await add('old', '', minutes: 0);
      final b = await add('new', '', minutes: 10);
      await add('pinned old', '', minutes: 1, pinned: true);
      expect(a.id, isNotNull);
      expect(a.id, isNot(b.id));
      expect(await titles(), ['pinned old', 'new', 'old']);
    });

    test('update changes the note in place', () async {
      final a = await add('before', 'x');
      await repo.save(a.copyWith(title: 'after'));
      expect(await titles(), ['after']);
    });

    test('search matches title or body and treats % literally', () async {
      await add('Milk', 'two litres');
      await add('100% plan', 'all in');
      await add('1000 steps', 'walk');
      expect(await titles(query: 'LITRES'), ['Milk']);
      expect(await titles(query: '100%'), ['100% plan']);
      expect(await titles(query: 'nothing like this'), isEmpty);
    });

    test('delete then restore brings the note back under its id', () async {
      final a = await add('keep me', 'body');
      await repo.delete(a.id!);
      expect(await titles(), isEmpty);
      await repo.restore(a);
      final back = ((await repo.byId(a.id!)) as Ok<Note?>).value!;
      expect(back.id, a.id);
      expect(back.title, 'keep me');
    });

    test('byId returns null for a missing note', () async {
      expect(((await repo.byId(999)) as Ok<Note?>).value, isNull);
    });
  });
}

void main() {
  sqfliteFfiInit();
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('organizer_'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // a handle may linger for a moment on Windows
    }
  });

  contract('in-memory fake', () async => FakeNotesRepository());
  contract('SQLite', () async {
    final db = await openOrganizerDatabase(
      databaseFactoryFfi,
      p.join(Directory.systemTemp.createTempSync('organizer_c_').path, 'o.db'),
    );
    addTearDown(db.close);
    return SqliteNotesRepository(db);
  });

  test('a fresh database reports the current schema version', () async {
    final db = await openOrganizerDatabase(
      databaseFactoryFfi,
      p.join(dir.path, 'v.db'),
    );
    final version = await db.getVersion();
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    )).map((r) => r['name']).toList();
    await db.close();
    writeCaptured(
      'po_ch22_schema.txt',
      'user_version: $version\ntables: $tables',
    );
    expect(version, organizerSchemaVersion);
    expect(tables, contains('notes'));
  });

  test('a storage failure becomes an Err with a readable message', () async {
    final db = await openOrganizerDatabase(
      databaseFactoryFfi,
      p.join(dir.path, 'closed.db'),
    );
    final repo = SqliteNotesRepository(db);
    await db.close(); // every later call fails
    final result = await repo.list();
    expect(result, isA<Err<List<Note>>>());
    expect((result as Err).message, 'Could not load your notes');
  });
}
