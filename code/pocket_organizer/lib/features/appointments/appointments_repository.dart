import 'package:sqflite/sqflite.dart';

import '../../core/result.dart';
import 'appointment.dart';

abstract interface class AppointmentsRepository {
  /// All appointments, earliest first.
  Future<Result<List<Appointment>>> list({String query = ''});
  Future<Result<Appointment>> save(Appointment appointment);
  Future<Result<Appointment?>> byId(int id);
  Future<Result<void>> delete(int id);
  Future<Result<Appointment>> restore(Appointment appointment);
}

class SqliteAppointmentsRepository implements AppointmentsRepository {
  SqliteAppointmentsRepository(this._db);

  final Database _db;

  @override
  Future<Result<List<Appointment>>> list({String query = ''}) =>
      _guard(() async {
        final rows = await _db.query(
          'appointments',
          orderBy: 'starts_at ASC, id ASC',
        );
        return rows.map(Appointment.fromMap).toList();
      }, 'Could not load your appointments');

  @override
  Future<Result<Appointment>> save(Appointment a) => _guard(() async {
    if (a.id == null) {
      final id = await _db.insert('appointments', a.toMap()..remove('id'));
      return a.copyWith(id: id);
    }
    final changed = await _db.update(
      'appointments',
      a.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [a.id],
    );
    if (changed == 0) throw StateError('Appointment ${a.id} no longer exists');
    return a;
  }, 'Could not save the appointment');

  @override
  Future<Result<Appointment?>> byId(int id) => _guard(() async {
    final rows = await _db.query(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Appointment.fromMap(rows.single);
  }, 'Could not open the appointment');

  @override
  Future<Result<void>> delete(int id) => _guard(() async {
    await _db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }, 'Could not delete the appointment');

  @override
  Future<Result<Appointment>> restore(Appointment a) => _guard(() async {
    await _db.insert(
      'appointments',
      a.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return a;
  }, 'Could not restore the appointment');

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
