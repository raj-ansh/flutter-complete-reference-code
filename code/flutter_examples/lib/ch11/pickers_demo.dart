import 'package:flutter/material.dart';

// #docregion pickers
/// Date and time pickers. Each `showXxx` function is asynchronous and returns
/// null when the user cancels.
class PickersDemo extends StatefulWidget {
  const PickersDemo({super.key, required this.today});

  /// Passed in (instead of calling DateTime.now()) so a test is repeatable.
  final DateTime today;

  @override
  State<PickersDemo> createState() => _PickersDemoState();
}

class _PickersDemoState extends State<PickersDemo> {
  DateTime? _date;
  TimeOfDay? _time;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.today,
      firstDate: DateTime(widget.today.year),
      lastDate: DateTime(widget.today.year + 1),
      currentDate: widget.today, // which day gets the "today" ring
    );
    // The widget may have left the screen while the dialog was open.
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 30),
    );
    if (!mounted || picked == null) return;
    setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final time = _time;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: _pickDate,
              child: const Text('Pick a date'),
            ),
            Text(
              date == null
                  ? 'No date'
                  : MaterialLocalizations.of(context).formatFullDate(date),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _pickTime,
              child: const Text('Pick a time'),
            ),
            Text(time == null ? 'No time' : time.format(context)),
          ],
        ),
      ),
    );
  }
}
// #enddocregion pickers
