import 'package:flutter/foundation.dart';

import '../../core/calendar_date.dart';

// #docregion task
@immutable
class Task {
  const Task({
    this.id,
    required this.title,
    this.due,
    this.done = false,
    this.completedAt,
  });

  final int? id;
  final String title;

  /// A calendar day, not an instant: see [CalendarDate].
  final CalendarDate? due;
  final bool done;

  /// When it was ticked off (UTC), for ordering the "done" section.
  final DateTime? completedAt;

  /// The nullable fields use the function-wrapper technique from Chapter 18:
  /// leave a parameter out to keep the value; pass `() => null` to clear it.
  Task copyWith({
    int? id,
    String? title,
    CalendarDate? Function()? due,
    bool? done,
    DateTime? Function()? completedAt,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    due: due != null ? due() : this.due,
    done: done ?? this.done,
    completedAt: completedAt != null ? completedAt() : this.completedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'due_date': due?.toIso(),
    'done': done ? 1 : 0,
    'completed_at': completedAt?.toUtc().millisecondsSinceEpoch,
  };

  factory Task.fromMap(Map<String, Object?> map) => Task(
    id: map['id']! as int,
    title: map['title']! as String,
    due: switch (map['due_date']) {
      final String text => CalendarDate.parse(text),
      _ => null,
    },
    done: map['done'] == 1,
    completedAt: switch (map['completed_at']) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      _ => null,
    },
  );
}
// #enddocregion task
