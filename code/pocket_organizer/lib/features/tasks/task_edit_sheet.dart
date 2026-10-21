import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/calendar_date.dart';
import '../../core/result.dart';
import 'task.dart';
import 'tasks_view_model.dart';

// #docregion tasksheet
/// A bottom sheet for creating or editing a task: a title and an optional day.
Future<void> showTaskSheet(BuildContext context, {Task? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // so the keyboard does not hide the buttons
    showDragHandle: true,
    builder: (sheetContext) => ChangeNotifierProvider<TasksViewModel>.value(
      // The sheet lives in its own route, outside the screen's provider scope.
      value: context.read<TasksViewModel>(),
      child: _TaskForm(existing: existing),
    ),
  );
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({this.existing});
  final Task? existing;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late CalendarDate? _due = widget.existing?.due;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final vm = context.read<TasksViewModel>();
    final today = vm.today.toLocalMidnight();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due?.toLocalMidnight() ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) {
      setState(() => _due = CalendarDate.fromDateTime(picked));
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the task a name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await context.read<TasksViewModel>().save(
      existing: widget.existing,
      title: _title.text,
      due: _due,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.pop(context);
      case Err(:final message):
        setState(() {
          _saving = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = _due;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Task', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(
                  due == null
                      ? 'Add a due date'
                      : DateFormat.yMMMd().format(due.toLocalMidnight()),
                ),
              ),
              if (due != null)
                IconButton(
                  tooltip: 'Remove the due date',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _due = null),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// #enddocregion tasksheet
