import 'package:flutter/foundation.dart';

import '../../core/calendar_date.dart';

// #docregion appointment
/// Something that happens at a specific moment, unlike a task's due *day*.
/// The start is a UTC instant: it is the same moment for everyone, and each
/// phone shows it in its own time zone.
@immutable
class Appointment {
  const Appointment({
    this.id,
    required this.title,
    required this.startsAt,
    this.durationMinutes = 60,
    this.location = '',
  });

  final int? id;
  final String title;
  final DateTime startsAt;
  final int durationMinutes;
  final String location;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  /// The calendar day it starts on, in the phone's time zone.
  CalendarDate get localDay => CalendarDate.fromDateTime(startsAt.toLocal());

  /// Two appointments overlap if each starts before the other ends. One that
  /// ends exactly when another starts does not overlap it.
  bool overlaps(Appointment other) =>
      startsAt.isBefore(other.endsAt) && other.startsAt.isBefore(endsAt);

  Appointment copyWith({
    int? id,
    String? title,
    DateTime? startsAt,
    int? durationMinutes,
    String? location,
  }) => Appointment(
    id: id ?? this.id,
    title: title ?? this.title,
    startsAt: startsAt ?? this.startsAt,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    location: location ?? this.location,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'starts_at': startsAt.toUtc().millisecondsSinceEpoch,
    'duration_minutes': durationMinutes,
    'location': location,
  };

  factory Appointment.fromMap(Map<String, Object?> map) => Appointment(
    id: map['id']! as int,
    title: map['title']! as String,
    startsAt: DateTime.fromMillisecondsSinceEpoch(
      map['starts_at']! as int,
      isUtc: true,
    ),
    durationMinutes: map['duration_minutes']! as int,
    location: map['location']! as String,
  );
}
// #enddocregion appointment
