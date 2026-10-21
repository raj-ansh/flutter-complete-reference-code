import '../../core/calendar_date.dart';
import '../../core/clock.dart';
import '../../core/list_view_model.dart';
import '../../core/result.dart';
import 'appointment.dart';
import 'appointments_repository.dart';

// #docregion appointmentsvm
class AppointmentsViewModel extends ListViewModel<Appointment> {
  AppointmentsViewModel(this._repository, this._clock) {
    _selected = today;
  }

  final AppointmentsRepository _repository;
  final Clock _clock;

  late CalendarDate _selected;

  CalendarDate get today => CalendarDate.fromDateTime(_clock.now().toLocal());

  /// The day whose appointments are listed under the month grid.
  CalendarDate get selectedDay => _selected;

  /// The first day of the month being shown.
  CalendarDate get month => CalendarDate(_selected.year, _selected.month, 1);

  void selectDay(CalendarDate day) {
    _selected = day;
    notifyListeners();
  }

  /// Shows the month [delta] months away, keeping the same day number where
  /// the month is long enough (31 January + 1 month selects 28 or 29 February).
  void moveMonth(int delta) {
    final first = DateTime(_selected.year, _selected.month + delta, 1);
    final last = CalendarDate.daysInMonth(first.year, first.month);
    _selected = CalendarDate(
      first.year,
      first.month,
      _selected.day > last ? last : _selected.day,
    );
    notifyListeners();
  }

  List<Appointment> get _all => switch (state) {
    ListLoaded<Appointment>(:final items) => items,
    _ => const [],
  };

  /// Days that have at least one appointment, for the dots on the grid.
  Set<CalendarDate> get busyDays => {for (final a in _all) a.localDay};

  List<Appointment> appointmentsOn(CalendarDate day) => [
    for (final a in _all)
      if (a.localDay == day) a,
  ];

  /// Existing appointments that [candidate] would overlap (other than itself).
  List<Appointment> conflictsFor(Appointment candidate) => [
    for (final a in _all)
      if (a.id != candidate.id && a.overlaps(candidate)) a,
  ];

  @override
  Future<Result<List<Appointment>>> fetch(String query) =>
      _repository.list(query: query);

  Future<Result<Appointment>> save(Appointment appointment) async {
    final result = await _repository.save(appointment);
    if (result is Ok<Appointment>) await reload();
    return result;
  }

  Future<Appointment?> find(int id) async {
    final result = await _repository.byId(id);
    return result is Ok<Appointment?> ? result.value : null;
  }

  Future<Appointment?> delete(Appointment appointment) async {
    final result = await _repository.delete(appointment.id!);
    await afterAction(result);
    return result is Ok ? appointment : null;
  }

  Future<void> undoDelete(Appointment appointment) async =>
      afterAction(await _repository.restore(appointment));
}
// #enddocregion appointmentsvm
