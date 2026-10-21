import 'package:flutter/foundation.dart';

// #docregion calendardate
/// A day on the calendar (year, month, day) with no time and no time zone.
/// "Due on 5 November" means the same day wherever the phone travels, unlike
/// "midnight in some zone", which is a different instant for each viewer.
@immutable
class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate(this.year, this.month, this.day);

  /// The calendar day a [DateTime] falls on, in that DateTime's own zone.
  /// Pass a local time to get the user's today.
  CalendarDate.fromDateTime(DateTime t) : this(t.year, t.month, t.day);

  /// Parses "2026-11-05". Throws [FormatException] for anything else.
  factory CalendarDate.parse(String text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (m == null) throw FormatException('Not a date (YYYY-MM-DD): $text');
    final date = CalendarDate(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
    );
    // Reject 2026-02-30 and 2026-13-01: DateTime would quietly roll them over
    // into the next month or year, so compare all three parts after the trip.
    if (CalendarDate.fromDateTime(date.toLocalMidnight()) != date) {
      throw FormatException('No such day: $text');
    }
    return date;
  }

  final int year;
  final int month;
  final int day;

  /// 1 = Monday ... 7 = Sunday, as in [DateTime.weekday].
  int get weekday => toLocalMidnight().weekday;

  DateTime toLocalMidnight() => DateTime(year, month, day);

  /// Adds whole calendar days. Done through DateTime's constructor so that
  /// month ends and leap years are handled, and daylight-saving changes do not
  /// move the result by an hour (adding a Duration would).
  CalendarDate addDays(int days) =>
      CalendarDate.fromDateTime(DateTime(year, month, day + days));

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// The text stored in the database; it sorts correctly as text.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDate other) => toIso().compareTo(other.toIso());

  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
// #enddocregion calendardate
