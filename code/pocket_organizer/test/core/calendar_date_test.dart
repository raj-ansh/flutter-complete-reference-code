import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_organizer/core/calendar_date.dart';

import '../support/capture.dart';

void main() {
  test('parse and format round-trip, and reject impossible days', () {
    final rows = StringBuffer();
    String attempt(String text) {
      try {
        return CalendarDate.parse(text).toString();
      } on FormatException catch (e) {
        return 'FormatException: ${e.message}';
      }
    }

    for (final text in [
      '2026-11-05',
      '2028-02-29',
      '2026-02-29',
      '2026-04-31',
      '2026-13-01',
      '5 Nov 2026',
    ]) {
      rows.writeln('${text.padRight(12)} -> ${attempt(text)}');
    }
    writeCaptured('po_ch23_calendar_date.txt', rows.toString());

    expect(CalendarDate.parse('2026-11-05'), const CalendarDate(2026, 11, 5));
    expect(CalendarDate.parse('2028-02-29').toIso(), '2028-02-29');
    expect(() => CalendarDate.parse('2026-02-29'), throwsFormatException);
    expect(() => CalendarDate.parse('2026-13-01'), throwsFormatException);
    expect(() => CalendarDate.parse('5 Nov 2026'), throwsFormatException);
  });

  test('addDays crosses month ends, year ends and leap days', () {
    expect(
      const CalendarDate(2026, 10, 31).addDays(1),
      const CalendarDate(2026, 11, 1),
    );
    expect(
      const CalendarDate(2026, 12, 31).addDays(1),
      const CalendarDate(2027, 1, 1),
    );
    expect(
      const CalendarDate(2028, 2, 28).addDays(1),
      const CalendarDate(2028, 2, 29),
    );
    expect(
      const CalendarDate(2026, 2, 28).addDays(1),
      const CalendarDate(2026, 3, 1),
    );
    expect(
      const CalendarDate(2026, 3, 1).addDays(-1),
      const CalendarDate(2026, 2, 28),
    );
  });

  test('daysInMonth knows leap years', () {
    expect(CalendarDate.daysInMonth(2026, 2), 28);
    expect(CalendarDate.daysInMonth(2028, 2), 29);
    expect(CalendarDate.daysInMonth(2100, 2), 28); // divisible by 100, not 400
    expect(CalendarDate.daysInMonth(2000, 2), 29);
    expect(CalendarDate.daysInMonth(2026, 12), 31);
  });

  test('ordering and equality', () {
    const a = CalendarDate(2026, 10, 16);
    expect(a == const CalendarDate(2026, 10, 16), isTrue);
    expect(a.isBefore(const CalendarDate(2026, 10, 17)), isTrue);
    expect(a.isBefore(a), isFalse);
    final sorted = [
      const CalendarDate(2027, 1, 1),
      a,
      const CalendarDate(2026, 9, 30),
    ]..sort();
    expect(sorted.first, const CalendarDate(2026, 9, 30));
    final seen = <CalendarDate>{a}..add(const CalendarDate(2026, 10, 16));
    expect(seen, hasLength(1)); // equal dates count once
  });

  test('weekday is Monday-based like DateTime', () {
    expect(const CalendarDate(2026, 10, 16).weekday, DateTime.friday);
    expect(const CalendarDate(2024, 1, 1).weekday, DateTime.monday);
  });
}
