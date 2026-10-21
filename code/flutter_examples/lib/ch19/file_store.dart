import 'dart:convert';
import 'dart:io';

import 'note.dart';

// #docregion jsonfile
/// Stores one JSON document in one file, safely.
class JsonFileStore {
  JsonFileStore(this.file);

  final File file;

  /// Returns the stored value, or [fallback] if the file does not exist or
  /// cannot be understood. A damaged file must not stop the app starting.
  Future<Object?> read({Object? fallback}) async {
    try {
      if (!await file.exists()) return fallback;
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return fallback;
    }
  }

  /// Writes to a temporary file, then renames it over the real one. A rename
  /// replaces the old file in one step, so a crash leaves either the old
  /// complete file or the new complete file, never half of each.
  Future<void> write(Object? value) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }
}
// #enddocregion jsonfile

// #docregion filenotes
/// NoteStore on top of a JSON file: simple and fine for a few hundred notes,
/// but every operation reads or rewrites the whole file.
class FileNoteStore implements NoteStore {
  FileNoteStore(this._store);

  final JsonFileStore _store;

  Future<List<Note>> _load() async {
    final data = await _store.read(fallback: const <Object?>[]);
    return [
      for (final item in data! as List<Object?>)
        Note.fromJson(item! as Map<String, Object?>),
    ];
  }

  @override
  Future<Note> add(String title, String body, DateTime now) async {
    final notes = await _load();
    final nextId = notes.fold<int>(0, (m, n) => n.id! > m ? n.id! : m) + 1;
    final note = Note(id: nextId, title: title, body: body, updatedAt: now);
    await _store.write([...notes, note].map((n) => n.toJson()).toList());
    return note;
  }

  @override
  Future<List<Note>> all() async {
    final notes = await _load();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<List<Note>> search(String text) async {
    final needle = text.toLowerCase();
    return [
      for (final n in await all())
        if (n.title.toLowerCase().contains(needle)) n,
    ];
  }

  @override
  Future<bool> delete(int id) async {
    final notes = await _load();
    final kept = notes.where((n) => n.id != id).toList();
    if (kept.length == notes.length) return false;
    await _store.write(kept.map((n) => n.toJson()).toList());
    return true;
  }

  @override
  Future<void> close() async {}
}
// #enddocregion filenotes
