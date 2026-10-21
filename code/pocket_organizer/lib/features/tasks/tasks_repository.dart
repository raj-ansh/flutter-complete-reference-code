import 'package:sqflite/sqflite.dart';

import '../../core/result.dart';
import 'task.dart';

abstract interface class TasksRepository {
  /// Open tasks first (soonest due date first, undated last), then finished
  /// ones (most recently finished first). A non-empty [query] filters by title.
  Future<Result<List<Task>>> list({String query = ''});
  Future<Result<Task>> save(Task task);
  Future<Result<Task?>> byId(int id);
  Future<Result<void>> delete(int id);
  Future<Result<Task>> restore(Task task);
}

// #docregion sqlitetasks
class SqliteTasksRepository implements TasksRepository {
  SqliteTasksRepository(this._db);

  final Database _db;

  @override
  Future<Result<List<Task>>> list({String query = ''}) => _guard(() async {
    final text = query.trim();
    final rows = await _db.query(
      'tasks',
      where: text.isEmpty ? null : r"title LIKE ? ESCAPE '\'",
      whereArgs: text.isEmpty ? null : [_like(text)],
      // Text dates in YYYY-MM-DD form sort correctly as plain text.
      orderBy:
          'done ASC, '
          'CASE WHEN done = 0 THEN (due_date IS NULL) END ASC, '
          'CASE WHEN done = 0 THEN due_date END ASC, '
          'completed_at DESC, id ASC',
    );
    return rows.map(Task.fromMap).toList();
  }, 'Could not load your tasks');

  @override
  Future<Result<Task>> save(Task task) => _guard(() async {
    if (task.id == null) {
      final id = await _db.insert('tasks', task.toMap()..remove('id'));
      return task.copyWith(id: id);
    }
    final changed = await _db.update(
      'tasks',
      task.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    if (changed == 0) throw StateError('Task ${task.id} no longer exists');
    return task;
  }, 'Could not save the task');

  @override
  Future<Result<Task?>> byId(int id) => _guard(() async {
    final rows = await _db.query('tasks', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Task.fromMap(rows.single);
  }, 'Could not open the task');

  @override
  Future<Result<void>> delete(int id) => _guard(() async {
    await _db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }, 'Could not delete the task');

  @override
  Future<Result<Task>> restore(Task task) => _guard(() async {
    await _db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return task;
  }, 'Could not restore the task');

  static String _like(String text) {
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

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
// #enddocregion sqlitetasks
