import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/calendar_date.dart';
import '../../core/list_screen_body.dart';
import 'task.dart';
import 'task_edit_sheet.dart';
import 'task_groups.dart';
import 'tasks_view_model.dart';

// #docregion tasksscreen
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TasksViewModel>();
    // Turn the flat task list into section headers followed by their tasks.
    final rows = vm.state.mapItems<Object>(
      (tasks) => [
        for (final (section, items) in groupTasks(tasks, vm.today)) ...[
          section,
          ...items,
        ],
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasks-fab',
        onPressed: () => showTaskSheet(context),
        tooltip: 'New task',
        child: const Icon(Icons.add),
      ),
      body: ListScreenBody<Object>(
        state: rows,
        onRetry: vm.load,
        emptyIcon: Icons.checklist,
        emptyTitle: 'Nothing to do',
        emptyHint: 'Tap + to add a task.',
        itemBuilder: (context, row) => switch (row) {
          TaskSection() => _SectionHeader(section: row),
          Task() => _TaskTile(task: row, today: vm.today),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});
  final TaskSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        section.title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: section == TaskSection.overdue
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.today});
  final Task task;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<TasksViewModel>();
    final due = task.due;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final removed = await vm.delete(task);
        if (removed == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted "${task.title}"'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => vm.undoDelete(removed),
              ),
            ),
          );
      },
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: task.done,
        onChanged: (_) => vm.toggleDone(task),
        title: Text(
          task.title,
          style: task.done
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: due == null ? null : Text(_describe(due, today)),
        secondary: IconButton(
          tooltip: 'Edit task',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => showTaskSheet(context, existing: task),
        ),
      ),
    );
  }

  static String _describe(CalendarDate due, CalendarDate today) {
    if (due == today) return 'Today';
    if (due == today.addDays(1)) return 'Tomorrow';
    if (due == today.addDays(-1)) return 'Yesterday';
    return DateFormat.yMMMd().format(due.toLocalMidnight());
  }
}
// #enddocregion tasksscreen
