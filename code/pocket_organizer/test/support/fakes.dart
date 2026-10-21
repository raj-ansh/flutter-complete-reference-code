import 'dart:async';

import 'package:pocket_organizer/core/clock.dart';
import 'package:pocket_organizer/core/result.dart';
import 'package:pocket_organizer/features/notes/note.dart';
import 'package:pocket_organizer/features/notes/notes_repository.dart';

/// A clock that only moves when the test says so.
class FixedClock implements Clock {
  FixedClock(this.current);
  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration d) => current = current.add(d);
}

// #docregion fakerepo
/// An in-memory repository for fast tests of view models and screens. It obeys
/// the same contract as the SQLite one; contract tests run against both.
class FakeNotesRepository implements NotesRepository {
  FakeNotesRepository([List<Note> initial = const []]) {
    for (final n in initial) {
      _notes[n.id ?? _nextId] = n.copyWith(id: n.id ?? _nextId++);
    }
  }

  final _notes = <int, Note>{};
  int _nextId = 1;

  /// While true every call fails, like a broken disk.
  bool failing = false;

  /// If set, `list` waits for this before answering (to test overlapping calls).
  Future<void> Function(String query)? listGate;

  Result<T> _fail<T>() => const Err('The storage is unavailable');

  @override
  Future<Result<List<Note>>> list({String query = ''}) async {
    await listGate?.call(query);
    if (failing) return _fail();
    final q = query.trim().toLowerCase();
    final notes =
        _notes.values
            .where(
              (n) =>
                  q.isEmpty ||
                  n.title.toLowerCase().contains(q) ||
                  n.body.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            final byTime = b.updatedAt.compareTo(a.updatedAt);
            return byTime != 0 ? byTime : b.id!.compareTo(a.id!);
          });
    return Ok(notes);
  }

  @override
  Future<Result<Note>> save(Note note) async {
    if (failing) return _fail();
    final saved = note.id == null ? note.copyWith(id: _nextId++) : note;
    _notes[saved.id!] = saved;
    return Ok(saved);
  }

  @override
  Future<Result<Note?>> byId(int id) async {
    if (failing) return _fail();
    return Ok(_notes[id]);
  }

  @override
  Future<Result<void>> delete(int id) async {
    if (failing) return _fail();
    _notes.remove(id);
    return const Ok(null);
  }

  @override
  Future<Result<Note>> restore(Note note) async {
    if (failing) return _fail();
    _notes[note.id!] = note;
    return Ok(note);
  }
}
// #enddocregion fakerepo
