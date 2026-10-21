import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/list_screen_body.dart';
import 'appointment.dart';
import 'appointments_view_model.dart';
import 'month_grid.dart';

// #docregion calendarscreen
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppointmentsViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton(
            onPressed: () => vm.selectDay(vm.today),
            child: const Text('Today'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar-fab',
        onPressed: () =>
            context.push('/calendar/new?day=${vm.selectedDay.toIso()}'),
        tooltip: 'New appointment',
        child: const Icon(Icons.add),
      ),
      body: ListScreenBody<Appointment>(
        // Only the selected day's appointments are listed under the grid.
        state: vm.state.mapItems<Appointment>(
          (all) => [
            for (final a in all)
              if (a.localDay == vm.selectedDay) a,
          ],
        ),
        onRetry: vm.load,
        header: MonthGrid(
          month: vm.month,
          selected: vm.selectedDay,
          today: vm.today,
          busyDays: vm.busyDays,
          onSelect: vm.selectDay,
          onMonthChanged: vm.moveMonth,
        ),
        emptyIcon: Icons.event_available,
        emptyTitle: 'Nothing planned',
        emptyHint: 'Tap + to add an appointment on this day.',
        itemBuilder: (context, a) => _AppointmentTile(appointment: a),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<AppointmentsViewModel>();
    final time = DateFormat.jm();
    final a = appointment;
    return Dismissible(
      key: ValueKey(a.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final removed = await vm.delete(a);
        if (removed == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted "${a.title}"'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => vm.undoDelete(removed),
              ),
            ),
          );
      },
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(a.title),
        subtitle: Text(
          '${time.format(a.startsAt.toLocal())} to ${time.format(a.endsAt.toLocal())}'
          '${a.location.isEmpty ? '' : ' · ${a.location}'}',
        ),
        onTap: () => context.push('/calendar/${a.id}'),
      ),
    );
  }
}
// #enddocregion calendarscreen
