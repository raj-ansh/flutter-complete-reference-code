import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_organizer/core/calendar_date.dart';
import 'package:pocket_organizer/core/database.dart';
import 'package:pocket_organizer/core/list_view_model.dart';
import 'package:pocket_organizer/core/result.dart';
import 'package:pocket_organizer/features/appointments/appointment.dart';
import 'package:pocket_organizer/features/appointments/appointments_repository.dart';
import 'package:pocket_organizer/features/appointments/appointments_view_model.dart';
import 'package:pocket_organizer/features/appointments/month_grid.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/capture.dart';
import '../../support/fakes.dart';
import '../../support/fakes_more.dart';
import '../../support/screenshot.dart';

/// An appointment that starts at a LOCAL wall-clock time, whatever zone the
/// computer running the test is in.
Appointment at(String title, DateTime local, {int minutes = 60}) => Appointment(
  title: title,
  startsAt: local.toUtc(),
  durationMinutes: minutes,
);

void contract(String name, Future<AppointmentsRepository> Function() create) {
  group('AppointmentsRepository contract: $name', () {
    late AppointmentsRepository repo;
    setUp(() async => repo = await create());

    test('earliest first; round trip keeps the instant', () async {
      final late = DateTime.utc(2026, 10, 20, 15);
      final early = DateTime.utc(2026, 10, 18, 8, 30);
      await repo.save(
        Appointment(title: 'late', startsAt: late, location: 'Café'),
      );
      await repo.save(Appointment(title: 'early', startsAt: early));
      final all = ((await repo.list()) as Ok<List<Appointment>>).value;
      expect(all.map((a) => a.title), ['early', 'late']);
      expect(all.first.startsAt, early);
      expect(all.first.startsAt.isUtc, isTrue);
      expect(all.last.location, 'Café');
    });

    test('update, delete, restore, missing id', () async {
      final saved = ((await repo.save(
        Appointment(title: 'a', startsAt: DateTime.utc(2026, 10, 18)),
      )) as Ok<Appointment>).value;
      await repo.save(saved.copyWith(title: 'renamed'));
      expect(
        ((await repo.byId(saved.id!)) as Ok<Appointment?>).value!.title,
        'renamed',
      );
      await repo.delete(saved.id!);
      expect(((await repo.byId(saved.id!)) as Ok<Appointment?>).value, isNull);
      await repo.restore(saved.copyWith(title: 'renamed'));
      expect(
        ((await repo.byId(saved.id!)) as Ok<Appointment?>).value!.id,
        saved.id,
      );
    });
  });
}

/// A phone-sized window. The default test window is 800 wide, which would
/// stretch the month grid's cells far taller than on a real phone.
void usePhoneWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  sqfliteFfiInit();

  contract('in-memory fake', () async => FakeAppointmentsRepository());
  contract('SQLite', () async {
    final db = await openOrganizerDatabase(
      databaseFactoryFfi,
      p.join(Directory.systemTemp.createTempSync('appts_').path, 'a.db'),
    );
    addTearDown(db.close);
    return SqliteAppointmentsRepository(db);
  });

  group('month layout', () {
    test('leading blanks put the 1st under its weekday', () {
      String describe(int y, int m) {
        final cells = monthCells(y, m);
        final lead = cells.takeWhile((c) => c == null).length;
        final days = cells.whereType<CalendarDate>().length;
        final weekday = DateTime(y, m, 1).weekday;
        return '$y-${m.toString().padLeft(2, '0')}: 1st is weekday $weekday, '
            '$lead blank cell(s) first, $days days, ${cells.length ~/ 7} week rows';
      }

      final rows = [
        describe(2026, 10), // Thursday
        describe(2026, 2), // Sunday: six blanks with a Monday start
        describe(2028, 2), // leap year
        describe(2024, 1), // starts on a Monday: no blanks
        describe(2026, 3), // starts on a Sunday and has 31 days
      ];
      writeCaptured('po_ch23_month_layout.txt', rows.join('\n'));

      final oct = monthCells(2026, 10);
      expect(oct.takeWhile((c) => c == null).length, 3);
      expect(oct.whereType<CalendarDate>().length, 31);
      expect(monthCells(2028, 2).whereType<CalendarDate>().length, 29);
      expect(monthCells(2024, 1).first, const CalendarDate(2024, 1, 1));
      expect(monthCells(2026, 2).takeWhile((c) => c == null).length, 6);
      for (final (y, m) in [(2026, 10), (2026, 2), (2028, 2), (2026, 3)]) {
        expect(monthCells(y, m).length % 7, 0);
      }
      // A Sunday start moves the blanks.
      expect(
        monthCells(
          2026,
          10,
          weekStart: DateTime.sunday,
        ).takeWhile((c) => c == null).length,
        4,
      );
    });
  });

  group('overlap', () {
    final nine = DateTime.utc(2026, 10, 16, 9);
    Appointment a(DateTime start, int minutes) =>
        Appointment(title: 't', startsAt: start, durationMinutes: minutes);

    test('touching is not overlapping; sharing a minute is', () {
      final first = a(nine, 60);
      expect(
        first.overlaps(a(nine.add(const Duration(hours: 1)), 30)),
        isFalse,
      );
      expect(
        first.overlaps(a(nine.subtract(const Duration(minutes: 30)), 30)),
        isFalse,
      );
      expect(
        first.overlaps(a(nine.add(const Duration(minutes: 59)), 30)),
        isTrue,
      );
      expect(
        first.overlaps(a(nine.subtract(const Duration(minutes: 1)), 30)),
        isTrue,
      );
      expect(first.overlaps(a(nine, 15)), isTrue); // inside
      expect(a(nine, 15).overlaps(first), isTrue); // and the other way round
    });
  });

  group('view model', () {
    late FakeAppointmentsRepository repo;
    late FixedClock clock;
    late AppointmentsViewModel vm;
    setUp(() {
      repo = FakeAppointmentsRepository();
      clock = FixedClock(DateTime.utc(2026, 10, 16, 9));
      vm = AppointmentsViewModel(repo, clock);
    });
    tearDown(() => vm.dispose());

    test('moving months clamps the day number', () async {
      vm.selectDay(const CalendarDate(2026, 1, 31));
      vm.moveMonth(1);
      expect(vm.selectedDay, const CalendarDate(2026, 2, 28));
      vm.moveMonth(-1);
      expect(vm.selectedDay, const CalendarDate(2026, 1, 28)); // not 31 again
      vm.selectDay(const CalendarDate(2027, 12, 15));
      vm.moveMonth(1);
      expect(vm.selectedDay, const CalendarDate(2028, 1, 15)); // across a year
      vm.moveMonth(-13);
      expect(vm.selectedDay, const CalendarDate(2026, 12, 15));
      expect(vm.month, const CalendarDate(2026, 12, 1));
    });

    test('busy days and the day list follow the local calendar day', () async {
      await vm.load();
      // 23:30 local on the 20th: in UTC this may already be the 21st or still
      // the 20th, depending on the zone. The app must use the local day.
      final lateEvening = DateTime(2026, 10, 20, 23, 30);
      await vm.save(at('late call', lateEvening));
      await vm.save(at('lunch', DateTime(2026, 10, 21, 12)));
      expect(vm.busyDays, {
        const CalendarDate(2026, 10, 20),
        const CalendarDate(2026, 10, 21),
      });
      expect(
        vm.appointmentsOn(const CalendarDate(2026, 10, 20)).map((a) => a.title),
        ['late call'],
      );
      final lines = StringBuffer(
        'this computer: UTC offset ${lateEvening.timeZoneOffset}\n'
        'which calendar day does each local time fall on, as stored (UTC) '
        'and as shown (local)?\n',
      );
      for (final local in [DateTime(2026, 10, 20, 1), lateEvening]) {
        lines.writeln(
          '  local $local -> UTC day ${CalendarDate.fromDateTime(local.toUtc())}'
          ', local day ${CalendarDate.fromDateTime(local)}',
        );
      }
      writeCaptured('po_ch23_local_day.txt', lines.toString());
    });

    test('conflicts ignore the appointment being edited', () async {
      await vm.load();
      await vm.save(at('standup', DateTime(2026, 10, 20, 9), minutes: 30));
      final standup = (vm.state as ListLoaded<Appointment>).items.single;
      final clash = at('review', DateTime(2026, 10, 20, 9, 15));
      expect(vm.conflictsFor(clash).map((a) => a.title), ['standup']);
      expect(vm.conflictsFor(standup), isEmpty); // not a conflict with itself
      final after = at('after', DateTime(2026, 10, 20, 9, 30));
      expect(vm.conflictsFor(after), isEmpty);
    });

    test('delete and undo; a failed load becomes ListFailed', () async {
      await vm.load();
      await vm.save(at('x', DateTime(2026, 10, 20, 9)));
      final only = (vm.state as ListLoaded<Appointment>).items.single;
      final removed = await vm.delete(only);
      expect((vm.state as ListLoaded<Appointment>).items, isEmpty);
      await vm.undoDelete(removed!);
      expect((vm.state as ListLoaded<Appointment>).items.single.id, only.id);
      repo.failing = true;
      await vm.load();
      expect(vm.state, isA<ListFailed<Appointment>>());
    });
  });

  group('screens', () {
    final day = DateTime(2026, 10, 16);

    TestApp seeded() => TestApp(
      appointments: FakeAppointmentsRepository([
        at('Dentist', DateTime(2026, 10, 16, 9), minutes: 45),
        at('Lunch with Sam', DateTime(2026, 10, 16, 12, 30), minutes: 90),
        at('Garden club', DateTime(2026, 10, 22, 18)),
      ]),
      // 09:00 UTC, which is the 16th in every zone from -9 to +14.
      now: DateTime(day.year, day.month, day.day, 12).toUtc(),
    );

    testWidgets('the grid marks busy days and lists the selected day', (
      tester,
    ) async {
      usePhoneWindow(tester);
      await tester.pumpWidget(seeded().widget(initialLocation: '/calendar'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Dentist'), findsOneWidget);
      expect(find.text('Lunch with Sam'), findsOneWidget);
      expect(find.text('Garden club'), findsNothing); // another day

      await tester.tap(find.bySemanticsLabel(RegExp('October 22, 2026')));
      await tester.pumpAndSettle();
      expect(find.text('Garden club'), findsOneWidget);
      expect(find.text('Dentist'), findsNothing);

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Nothing planned'), findsOneWidget);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('create an appointment and see the conflict warning', (
      tester,
    ) async {
      usePhoneWindow(tester);
      final t = seeded();
      await tester.pumpWidget(t.widget(initialLocation: '/calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New appointment'));
      await tester.pumpAndSettle();
      expect(find.text('New appointment'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Give the appointment a title'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Call Mum',
      );
      await tester.pumpAndSettle();
      // The form starts at 09:00 on the selected day, where "Dentist" is.
      expect(find.textContaining('Overlaps with "Dentist"'), findsOneWidget);

      await tester.tap(find.text('Save')); // allowed despite the warning
      await tester.pumpAndSettle();
      expect(find.text('Call Mum'), findsOneWidget);
      final saved = t.appointments.items.values.firstWhere(
        (a) => a.title == 'Call Mum',
      );
      expect(saved.startsAt.toLocal().hour, 9);
      expect(saved.durationMinutes, 60);
    });

    testWidgets('screens for the book', (tester) async {
      await saveScreenshot(
        tester,
        seeded().widget(initialLocation: '/calendar'),
        'po_ch23_calendar',
        size: const Size(360, 640),
      );
      await saveScreenshot(
        tester,
        seeded().widget(initialLocation: '/calendar/new?day=2026-10-16'),
        'po_ch23_appointment_edit',
        size: const Size(360, 560),
        beforeCapture: (t) async {
          await t.enterText(
            find.widgetWithText(TextField, 'Title'),
            'Call Mum',
          );
          await t.pumpAndSettle();
        },
      );
    });
  });
}
