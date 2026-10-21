import 'package:sqflite/sqflite.dart';

import 'note.dart';

// #docregion open
/// Opens (and if necessary creates or upgrades) the notes database.
/// [factory] is a parameter so tests can use the desktop implementation.
Future<Database> openNotesDatabase(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('CREATE INDEX idx_notes_updated ON notes(updated_at)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // One step per version, in order, so any old version can catch up.
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'CREATE INDEX idx_notes_updated ON notes(updated_at)',
          );
        }
      },
    ),
  );
}
// #enddocregion open

// #docregion sqlitenotes
class SqliteNoteStore implements NoteStore {
  SqliteNoteStore(this._db);

  final Database _db;

  @override
  Future<Note> add(String title, String body, DateTime now) async {
    final note = Note(title: title, body: body, updatedAt: now);
    final values = note.toMap()..remove('id'); // let the database choose it
    final id = await _db.insert('notes', values);
    return note.copyWith(id: id);
  }

  @override
  Future<List<Note>> all() async {
    final rows = await _db.query('notes', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  @override
  Future<List<Note>> search(String text) async {
    // Escape LIKE's own wildcards so that "100%" means a literal percent.
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await _db.query(
      'notes',
      where: r"title LIKE ? ESCAPE '\'",
      whereArgs: ['%$escaped%'], // values travel separately from the SQL
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  @override
  Future<bool> delete(int id) async {
    final count = await _db.delete('notes', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  @override
  Future<void> close() => _db.close();
}
// #enddocregion sqlitenotes
