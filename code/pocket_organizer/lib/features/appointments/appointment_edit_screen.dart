import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/calendar_date.dart';
import '../../core/navigation.dart';
import '../../core/result.dart';
import 'appointment.dart';
import 'appointments_view_model.dart';

// #docregion appointmentedit
class AppointmentEditScreen extends StatefulWidget {
  const AppointmentEditScreen({super.key, this.appointmentId, this.initialDay});

  /// Null when creating.
  final int? appointmentId;

  /// The day to start on when creating.
  final CalendarDate? initialDay;

  @override
  State<AppointmentEditScreen> createState() => _AppointmentEditScreenState();
}

class _AppointmentEditScreenState extends State<AppointmentEditScreen> {
  static const _durations = [15, 30, 45, 60, 90, 120];

  final _title = TextEditingController();
  final _location = TextEditingController();
  Appointment? _existing;
  late DateTime _start; // local wall-clock time, converted to UTC on save
  int _duration = 60;
  bool _loading = true;
  bool _missing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final vm = context.read<AppointmentsViewModel>();
    final day = widget.initialDay ?? vm.today;
    _start = DateTime(day.year, day.month, day.day, 9); // default: 9 o'clock
    _open();
  }

  Future<void> _open() async {
    final id = widget.appointmentId;
    if (id != null) {
      final found = await context.read<AppointmentsViewModel>().find(id);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _loading = false;
          _missing = true;
        });
        return;
      }
      _existing = found;
      _title.text = found.title;
      _location.text = found.location;
      _start = found.startsAt.toLocal();
      _duration = found.durationMinutes;
    }
    setState(() => _loading = false);
  }

  /// The appointment as the form currently describes it.
  Appointment _candidate() => Appointment(
    id: _existing?.id,
    title: _title.text.trim(),
    startsAt: _start.toUtc(),
    durationMinutes: _duration,
    location: _location.text.trim(),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(_start.year - 1),
      lastDate: DateTime(_start.year + 5),
    );
    if (picked == null) return;
    setState(
      () => _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (picked == null) return;
    setState(
      () => _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the appointment a title');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await context.read<AppointmentsViewModel>().save(
      _candidate(),
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        context.read<AppointmentsViewModel>().selectDay(value.localDay);
        context.closeEditor('/calendar');
      case Err(:final message):
        setState(() {
          _saving = false;
          _error = message;
        });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppointmentsViewModel>();
    final conflicts = _loading
        ? <Appointment>[]
        : vm.conflictsFor(_candidate());
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appointmentId == null ? 'New appointment' : 'Edit appointment',
        ),
        actions: [
          TextButton(
            onPressed: (_saving || _loading || _missing) ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _missing
          ? const Center(child: Text('This appointment no longer exists.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    errorText: _error,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event),
                        label: Text(DateFormat.yMMMd().format(_start)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(DateFormat.jm().format(_start)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _duration,
                  decoration: const InputDecoration(labelText: 'Length'),
                  items: [
                    for (final m in _durations)
                      DropdownMenuItem(value: m, child: Text('$m minutes')),
                  ],
                  onChanged: (m) => setState(() => _duration = m ?? _duration),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Place (optional)',
                  ),
                ),
                if (conflicts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber),
                      title: Text(
                        'Overlaps with ${conflicts.map((c) => '"${c.title}"').join(', ')}',
                      ),
                      subtitle: const Text('You can still save it.'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
// #enddocregion appointmentedit
