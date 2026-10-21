import '../../core/calendar_date.dart';
import '../../core/clock.dart';
import '../../core/list_view_model.dart';
import '../../core/result.dart';
import 'task.dart';
import 'tasks_repository.dart';

// #docregion tasksvm
class TasksViewModel extends ListViewModel<Task> {
  TasksViewModel(this._repository, this._clock);

  final TasksRepository _repository;
  final Clock _clock;

  /// The user's today: the current instant seen in the phone's time zone.
  CalendarDate get today => CalendarDate.fromDateTime(_clock.now().toLocal());

  @override
  Future<Result<List<Task>>> fetch(String query) =>
      _repository.list(query: query);

  Future<Result<Task>> save({
    Task? existing,
    required String title,
    CalendarDate? due,
  }) async {
    final base = existing ?? const Task(title: '');
    final result = await _repository.save(
      base.copyWith(title: title.trim(), due: () => due),
    );
    if (result is Ok<Task>) await reload();
    return result;
  }

  /// Ticking records when; un-ticking forgets it.
  Future<void> toggleDone(Task task) async {
    final nowDone = !task.done;
    await afterAction(
      await _repository.save(
        task.copyWith(
          done: nowDone,
          completedAt: () => nowDone ? _clock.now() : null,
        ),
      ),
    );
  }

  Future<Task?> delete(Task task) async {
    final result = await _repository.delete(task.id!);
    await afterAction(result);
    return result is Ok ? task : null;
  }

  Future<void> undoDelete(Task task) async =>
      afterAction(await _repository.restore(task));
}
// #enddocregion tasksvm
