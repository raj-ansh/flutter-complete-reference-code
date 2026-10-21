import '../../core/clock.dart';
import '../../core/list_view_model.dart';
import '../../core/result.dart';
import 'note.dart';
import 'notes_repository.dart';

// #docregion viewmodel
/// Notes: the shared list behavior plus the commands specific to notes.
class NotesViewModel extends ListViewModel<Note> {
  NotesViewModel(this._repository, this._clock);

  final NotesRepository _repository;
  final Clock _clock;

  @override
  Future<Result<List<Note>>> fetch(String query) =>
      _repository.list(query: query);

  /// Creates or updates a note. The result tells the editor whether to close.
  Future<Result<Note>> save({
    Note? existing,
    required String title,
    required String body,
  }) async {
    final now = _clock.now();
    final note = (existing ?? Note(title: '', body: '', updatedAt: now))
        .copyWith(title: title, body: body, updatedAt: now);
    final result = await _repository.save(note);
    if (result is Ok<Note>) await reload();
    return result;
  }

  Future<void> togglePin(Note note) async =>
      afterAction(await _repository.save(note.copyWith(pinned: !note.pinned)));

  /// Deletes a note and returns it so the screen can offer Undo.
  Future<Note?> delete(Note note) async {
    final result = await _repository.delete(note.id!);
    await afterAction(result);
    return result is Ok ? note : null;
  }

  Future<void> undoDelete(Note note) async =>
      afterAction(await _repository.restore(note));

  /// Opens one note for editing, or null if it does not exist.
  Future<Note?> find(int id) async {
    final result = await _repository.byId(id);
    return result is Ok<Note?> ? result.value : null;
  }
}
// #enddocregion viewmodel
