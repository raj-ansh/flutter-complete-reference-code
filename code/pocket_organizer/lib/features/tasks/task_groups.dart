import '../../core/calendar_date.dart';
import 'task.dart';

// #docregion groups
enum TaskSection {
  overdue('Overdue'),
  today('Today'),
  upcoming('Upcoming'),
  noDate('No date'),
  done('Done');

  const TaskSection(this.title);
  final String title;
}

/// Which section a task belongs in on the day [today].
TaskSection sectionOf(Task task, CalendarDate today) {
  if (task.done) return TaskSection.done; // a finished task is never overdue
  final due = task.due;
  if (due == null) return TaskSection.noDate;
  if (due.isBefore(today)) return TaskSection.overdue;
  if (due == today) return TaskSection.today;
  return TaskSection.upcoming;
}

/// Splits tasks into the sections, in the order they should be shown, and
/// leaves out sections with nothing in them. Order inside a section is the
/// order of [tasks].
List<(TaskSection, List<Task>)> groupTasks(
  List<Task> tasks,
  CalendarDate today,
) {
  final groups = {for (final s in TaskSection.values) s: <Task>[]};
  for (final t in tasks) {
    groups[sectionOf(t, today)]!.add(t);
  }
  return [
    for (final s in TaskSection.values)
      if (groups[s]!.isNotEmpty) (s, groups[s]!),
  ];
}
// #enddocregion groups
