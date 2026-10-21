// SNAPSHOT: this file is the version at the end of Chapter 22. Chapter 23
// refactors it onto the shared ListViewModel; see the final project for that.
// It is kept here (not compiled) so that the Chapter 22 listings match the code
// the Chapter 22 tests ran against.
import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../../core/result.dart';
import 'note.dart';
import 'notes_repository.dart';

// #docregion state
sealed class NotesState {
  const NotesState();
}

final class NotesLoading extends NotesState {
  const NotesLoading();
}

final class NotesLoaded extends NotesState {
  const NotesLoaded(this.notes, {this.query = '', this.message});
  final List<Note> notes;
  final String query;

  /// A problem with the last action; the list stays visible.
  final String? message;

  bool get isSearching => query.trim().isNotEmpty;
}

final class NotesFailed extends NotesState {
  const NotesFailed(this.message);
  final String message;
}
// #enddocregion state

// #docregion viewmodel
class NotesViewModel extends ChangeNotifier {
  NotesViewModel(this._repository, this._clock);

  final NotesRepository _repository;
  final Clock _clock;

  NotesState _state = const NotesLoading();
  NotesState get state => _state;
  String _query = '';
  bool _disposed = false;
  int _generation = 0;

  Future<void> load() async {
    _set(const NotesLoading());
    await _reload();
  }

  Future<void> search(String query) async {
    _query = query;
    await _reload();
  }

  /// Creates or updates a note. Returns the saved note, or null on failure
  /// (the screen then keeps the editor open and shows the message).
  Future<Result<Note>> save({Note? existing, required String title, required String body}) async {
    final note = (existing ?? Note(title: '', body: '', updatedAt: _clock.now()))
        .copyWith(title: title, body: body, updatedAt: _clock.now());
    final result = await _repository.save(note);
    if (result is Ok<Note>) await _reload();
    return result;
  }

  Future<void> togglePin(Note note) async {
    final result = await _repository.save(note.copyWith(pinned: !note.pinned));
    await _afterAction(result);
  }

  /// Deletes a note and returns it so the screen can offer Undo.
  Future<Note?> delete(Note note) async {
    final result = await _repository.delete(note.id!);
    await _afterAction(result);
    return result is Ok ? note : null;
  }

  Future<void> undoDelete(Note note) async {
    final result = await _repository.restore(note);
    await _afterAction(result);
  }

  Future<void> _afterAction(Result<Object?> result) async {
    switch (result) {
      case Ok():
        await _reload();
      case Err(:final message):
        final current = _state;
        _set(
          current is NotesLoaded
              ? NotesLoaded(current.notes, query: _query, message: message)
              : NotesFailed(message),
        );
    }
  }

  /// Opens one note for editing, or null if it does not exist.
  Future<Note?> find(int id) async {
    final result = await _repository.byId(id);
    return result is Ok<Note?> ? result.value : null;
  }

  Future<void> _reload() async {
    // Searches can overlap. Only the newest request may update the screen,
    // otherwise a slow answer to "ba" could overwrite the answer to "basil".
    final generation = ++_generation;
    final result = await _repository.list(query: _query);
    if (generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _set(NotesLoaded(value, query: _query));
      case Err(:final message):
        _set(NotesFailed(message));
    }
  }

  void _set(NotesState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
// #enddocregion viewmodel
