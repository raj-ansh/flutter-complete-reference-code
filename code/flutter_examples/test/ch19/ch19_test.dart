import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_examples/ch19/file_store.dart';
import 'package:flutter_examples/ch19/note.dart';
import 'package:flutter_examples/ch19/settings_store.dart';
import 'package:flutter_examples/ch19/sqlite_store.dart';
import 'package:flutter_examples/ch19/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/capture.dart';

late Directory tempDir;

/// Makes a fresh implementation of NoteStore. [reopen] gives a new object on
/// the same stored data, as if the app had been restarted.
class Impl {
  Impl(this.name, this.open);
  final String name;
  final Future<NoteStore> Function(String dir) open;
}

final impls = [
  Impl(
    'JSON file',
    (dir) async => FileNoteStore(JsonFileStore(File(p.join(dir, 'notes.json')))),
  ),
  Impl('SQLite', (dir) async {
    final db = await openNotesDatabase(
      databaseFactoryFfi,
      p.join(dir, 'notes.db'),
    );
    return SqliteNoteStore(db);
  }),
];

final t0 = DateTime.utc(2026, 10, 16, 9);

void main() {
  sqfliteFfiInit();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ch19_');
  });
  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a file handle for an instant; the temp
      // directory is disposable.
    }
  });

  for (final impl in impls) {
    group('NoteStore contract: ${impl.name}', () {
      test('add, list newest first, search, delete', () async {
        final store = await impl.open(tempDir.path);
        final a = await store.add('Milk', 'two litres', t0);
        final b = await store.add(
          'Basil plan',
          'repot',
          t0.add(const Duration(hours: 1)),
        );
        await store.add('100% done', 'literal percent', t0);
        await store.add('1000 steps', 'walk', t0);

        expect(a.id, isNotNull);
        expect(a.id, isNot(b.id));
        final all = await store.all();
        expect(all.first.title, 'Basil plan'); // newest first
        expect((await store.search('basil')).map((n) => n.title), [
          'Basil plan',
        ]);
        // % is an ordinary character in a search, not a wildcard.
        expect((await store.search('100%')).map((n) => n.title), ['100% done']);
        expect(await store.delete(a.id!), isTrue);
        expect(await store.delete(a.id!), isFalse);
        await store.close();
      });

      test('data survives closing and reopening', () async {
        var store = await impl.open(tempDir.path);
        await store.add('Remember me', 'body', t0);
        await store.close();
        store = await impl.open(tempDir.path);
        final notes = await store.all();
        expect(notes.single.title, 'Remember me');
        expect(notes.single.updatedAt, t0);
        expect(notes.single.updatedAt.isUtc, isTrue);
        await store.close();
      });
    });
  }

  group('JSON file', () {
    test('missing and damaged files fall back; writes leave no temp file', () async {
      final file = File(p.join(tempDir.path, 'sub', 'settings.json'));
      final store = JsonFileStore(file);
      final missing = await store.read(fallback: 'default');

      await store.write({'theme': 'dark', 'sizes': [1, 2]});
      final good = await store.read();
      final tempLeft = File('${file.path}.tmp').existsSync();

      await file.writeAsString('{"theme": "dar'); // a half-written file
      final damaged = await store.read(fallback: 'default');

      writeCaptured(
        'ch19_json_file.txt',
        'file does not exist yet:      $missing\n'
            'after write, read back:       $good\n'
            'temporary file left behind:   $tempLeft\n'
            'file cut off mid-write:       $damaged',
      );
      expect(missing, 'default');
      expect(tempLeft, isFalse);
      expect(damaged, 'default');
    });
  });

  group('SQLite', () {
    late Database db;
    setUp(() async {
      db = await openNotesDatabase(
        databaseFactoryFfi,
        p.join(tempDir.path, 'q.db'),
      );
      final store = SqliteNoteStore(db);
      await store.add('Groceries', 'milk', t0);
      await store.add('Secrets', 'hunter2', t0);
    });
    tearDown(() => db.close());

    test('string-built SQL is injectable; parameters are not', () async {
      const hostile = "x' OR '1'='1";
      final unsafe = await db.rawQuery(
        "SELECT title FROM notes WHERE title = '$hostile'",
      );
      final safe = await db.query(
        'notes',
        columns: ['title'],
        where: 'title = ?',
        whereArgs: [hostile],
      );
      writeCaptured(
        'ch19_injection.txt',
        'search text typed by a user:  $hostile\n'
            '\n'
            "built with string interpolation:  WHERE title = '$hostile'\n"
            '  rows returned: ${unsafe.length}  ${unsafe.map((r) => r['title']).toList()}\n'
            '\n'
            'built with whereArgs:             WHERE title = ?\n'
            '  rows returned: ${safe.length}',
      );
      expect(unsafe.length, 2);
      expect(safe, isEmpty);
    });

    test('a transaction is all or nothing', () async {
      Future<int> count() async =>
          Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM notes'))!;
      final before = await count();
      Object? caught;
      try {
        await db.transaction((txn) async {
          await txn.insert('notes', {
            'title': 'A',
            'body': 'x',
            'updated_at': 1,
          });
          await txn.insert('notes', {
            'title': null, // violates NOT NULL
            'body': 'x',
            'updated_at': 1,
          });
        });
      } on DatabaseException catch (e) {
        caught = e;
      }
      final afterFailure = await count();
      await db.transaction((txn) async {
        for (final t in ['B', 'C']) {
          await txn.insert('notes', {
            'title': t,
            'body': 'x',
            'updated_at': 1,
          });
        }
      });
      final afterSuccess = await count();
      writeCaptured(
        'ch19_transaction.txt',
        'rows before:                         $before\n'
            'transaction with a failing insert:   ${caught.runtimeType}\n'
            'rows after the failed transaction:   $afterFailure\n'
            'rows after a successful one (+2):    $afterSuccess',
      );
      expect(afterFailure, before);
      expect(afterSuccess, before + 2);
    });

    test('the index is used for ordering by date', () async {
      Future<String> plan(String sql) async {
        final rows = await db.rawQuery('EXPLAIN QUERY PLAN $sql');
        return rows.map((r) => r['detail']).join('; ');
      }

      final indexed = await plan('SELECT * FROM notes ORDER BY updated_at DESC');
      final unindexed = await plan('SELECT * FROM notes ORDER BY title');
      final version = (await db.rawQuery(
        'SELECT sqlite_version() AS v',
      )).single['v'];
      writeCaptured(
        'ch19_query_plan.txt',
        'SQLite library used by this test: $version\n'
            '\n'
            'ORDER BY updated_at DESC (has an index):\n  $indexed\n'
            'ORDER BY title (no index):\n  $unindexed',
      );
      expect(indexed, contains('idx_notes_updated'));
      expect(unindexed, isNot(contains('idx_notes_updated')));
    });
  });

  test('migration from version 1 keeps the data', () async {
    final path = p.join(tempDir.path, 'old.db');
    // An old install: version 1 had no "pinned" column and no index.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) => db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )'''),
      ),
    );
    await v1.insert('notes', {
      'title': 'Written by version 1',
      'body': 'old data',
      'updated_at': t0.millisecondsSinceEpoch,
    });
    final oldColumns = (await v1.rawQuery('PRAGMA table_info(notes)'))
        .map((r) => r['name'])
        .toList();
    await v1.close();

    final v2 = await openNotesDatabase(databaseFactoryFfi, path); // upgrade
    final newColumns = (await v2.rawQuery('PRAGMA table_info(notes)'))
        .map((r) => r['name'])
        .toList();
    final version = await v2.getVersion();
    final notes = await SqliteNoteStore(v2).all();
    final indexes = (await v2.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
    )).map((r) => r['name']).toList();
    await v2.close();

    writeCaptured(
      'ch19_migration.txt',
      'columns in the version 1 file: $oldColumns\n'
          'after opening with version 2:  $newColumns  (user_version = $version)\n'
          'indexes created by upgrade:    $indexes\n'
          'old note still there:          "${notes.single.title}", '
          'pinned = ${notes.single.pinned}',
    );
    expect(newColumns, contains('pinned'));
    expect(notes.single.title, 'Written by version 1');
    expect(notes.single.pinned, isFalse);
    expect(version, 2);
  });

  test('dates are stored as UTC instants', () {
    final local = DateTime(2026, 10, 16, 9, 30); // a local wall-clock time
    final note = Note(title: 't', body: 'b', updatedAt: local);
    final restored = Note.fromMap(note.toMap());
    final viaJson = Note.fromJson(note.toJson());
    writeCaptured(
      'ch19_dates.txt',
      'created from a local time:     isUtc = ${local.isUtc}\n'
          'stored as milliseconds:        ${note.toMap()['updated_at']}\n'
          'restored from the database:    isUtc = ${restored.updatedAt.isUtc}, '
          'same instant = ${restored.updatedAt.isAtSameMomentAs(local)}\n'
          'JSON text:                     ${note.toJson()['updatedAt']}\n'
          'restored from JSON:            same instant = '
          '${viaJson.updatedAt.isAtSameMomentAs(local)}',
    );
    expect(restored.updatedAt.isAtSameMomentAs(local), isTrue);
    expect(restored.updatedAt.isUtc, isTrue);
    expect(viaJson.updatedAt.isAtSameMomentAs(local), isTrue);
  });

  group('key-value settings', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('defaults, saving, and restoring after a restart', () async {
      var settings = await SettingsStore.open();
      final defaults =
          '${settings.themeMode}, newestFirst=${settings.newestFirst}, '
          'launches=${settings.launchCount}';
      await settings.setThemeMode(ThemeMode.dark);
      await settings.setNewestFirst(false);
      await settings.recordLaunch();
      await settings.recordLaunch();

      settings = await SettingsStore.open(); // a "restart"
      final restored =
          '${settings.themeMode}, newestFirst=${settings.newestFirst}, '
          'launches=${settings.launchCount}';

      final raw = SharedPreferencesAsync();
      final stored = await raw.getString('settings.themeMode');
      await raw.setString('settings.themeMode', 'neon'); // unknown value
      settings = await SettingsStore.open();
      writeCaptured(
        'ch19_settings.txt',
        'first run (defaults):          $defaults\n'
            'after saving and restarting:   $restored\n'
            'the stored theme text is:      "$stored"\n'
            'a damaged value "neon" reads:  ${settings.themeMode}',
      );
      expect(restored, 'ThemeMode.dark, newestFirst=false, launches=2');
      expect(settings.themeMode, ThemeMode.system);
    });
  });

  test('the token wrapper reads, saves and clears', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final tokens = TokenStore();
    expect(await tokens.read(), isNull);
    await tokens.save('abc123');
    expect(await tokens.read(), 'abc123');
    await tokens.clear();
    expect(await tokens.read(), isNull);
  });
}
