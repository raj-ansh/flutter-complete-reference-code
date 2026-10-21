import 'package:sqflite/sqflite.dart';

import '../../core/result.dart';
import 'note.dart';

// #docregion contract
/// Everything the rest of the app may do with notes.
abstract interface class NotesRepository {
  /// Pinned notes first, then newest first. A non-empty [query] keeps notes
  /// whose title or body contains it (SQLite ignores case for ASCII letters only).
  Future<Result<List<Note>>> list({String query = ''});

  /// Inserts when [note] has no id, updates otherwise. Returns the saved note.
  Future<Result<Note>> save(Note note);

  /// The note with [id], or null if there is none.
  Future<Result<Note?>> byId(int id);

  Future<Result<void>> delete(int id);

  /// Puts a deleted note back under its original id (for Undo).
  Future<Result<Note>> restore(Note note);
}
// #enddocregion contract

// #docregion sqlite
class SqliteNotesRepository implements NotesRepository {
  SqliteNotesRepository(this._db);

  final Database _db;

  @override
  Future<Result<List<Note>>> list({String query = ''}) => _guard(() async {
    final text = query.trim();
    final rows = await _db.query(
      'notes',
      where: text.isEmpty
          ? null
          : r"(title LIKE ? ESCAPE '\' OR body LIKE ? ESCAPE '\')",
      whereArgs: text.isEmpty ? null : [_like(text), _like(text)],
      orderBy: 'pinned DESC, updated_at DESC, id DESC',
    );
    return rows.map(Note.fromMap).toList();
  }, 'Could not load your notes');

  @override
  Future<Result<Note>> save(Note note) => _guard(() async {
    if (note.id == null) {
      final id = await _db.insert('notes', note.toMap()..remove('id'));
      return note.copyWith(id: id);
    }
    final changed = await _db.update(
      'notes',
      note.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    if (changed == 0) throw StateError('Note ${note.id} no longer exists');
    return note;
  }, 'Could not save the note');

  @override
  Future<Result<Note?>> byId(int id) => _guard(() async {
    final rows = await _db.query('notes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Note.fromMap(rows.single);
  }, 'Could not open the note');

  @override
  Future<Result<void>> delete(int id) => _guard(() async {
    await _db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }, 'Could not delete the note');

  @override
  Future<Result<Note>> restore(Note note) => _guard(() async {
    await _db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return note;
  }, 'Could not restore the note');

  /// Builds a LIKE pattern in which the user's % and _ are ordinary characters.
  static String _like(String text) {
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  /// Turns exceptions into a user-readable [Err]. The technical detail is for
  /// logs (Chapter 28), not for the screen.
  Future<Result<T>> _guard<T>(
    Future<T> Function() action,
    String message,
  ) async {
    try {
      return Ok(await action());
    } on Object {
      return Err(message);
    }
  }
}
// #enddocregion sqlite
