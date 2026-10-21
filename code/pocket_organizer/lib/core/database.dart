import 'package:sqflite/sqflite.dart';

// #docregion database
/// The schema version of the database file. Bump it when the schema changes
/// and add a step to [_upgrade].
const organizerSchemaVersion = 2;

/// Opens the one database file that holds all of the app's records.
Future<Database> openOrganizerDatabase(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: organizerSchemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _upgrade(db, 0, version),
      onUpgrade: _upgrade,
    ),
  );
}

/// One block per schema version, applied in order. A fresh install runs
/// every block from 0; an old install runs only the ones it missed. Never edit
/// an old block after release: add a new one.
Future<void> _upgrade(Database db, int from, int to) async {
  if (from < 1) {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_notes_updated ON notes(updated_at)');
  }
  if (from < 2) {
    // Version 2 adds the other three features. Existing notes are untouched.
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        due_date TEXT,
        done INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER
      )''');
    await db.execute('CREATE INDEX idx_tasks_due ON tasks(due_date)');
    await db.execute('''
      CREATE TABLE appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        starts_at INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 60,
        location TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute(
      'CREATE INDEX idx_appointments_start ON appointments(starts_at)',
    );
    await db.execute('''
      CREATE TABLE contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        photo_path TEXT
      )''');
  }
}
// #enddocregion database
