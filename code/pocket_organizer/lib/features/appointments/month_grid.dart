import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/calendar_date.dart';

// #docregion monthcells
/// The cells of a month grid: empty cells (null) before the 1st so that the
/// 1st falls under its weekday, then one cell per day, then empty cells to
/// complete the last week. [weekStart] is a [DateTime] weekday constant.
List<CalendarDate?> monthCells(
  int year,
  int month, {
  int weekStart = DateTime.monday,
}) {
  final firstWeekday = DateTime(year, month, 1).weekday;
  final leading = (firstWeekday - weekStart + 7) % 7;
  final days = CalendarDate.daysInMonth(year, month);
  final cells = <CalendarDate?>[
    for (var i = 0; i < leading; i++) null,
    for (var d = 1; d <= days; d++) CalendarDate(year, month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}
// #enddocregion monthcells

// #docregion monthgrid
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.busyDays,
    required this.onSelect,
    required this.onMonthChanged,
  });

  /// The first day of the month shown.
  final CalendarDate month;
  final CalendarDate selected;
  final CalendarDate today;
  final Set<CalendarDate> busyDays;
  final ValueChanged<CalendarDate> onSelect;

  /// Called with -1 for the previous month and +1 for the next.
  final ValueChanged<int> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cells = monthCells(month.year, month.month);
    // 1 January 2024 was a Monday, which gives the weekday names in order.
    final weekdayNames = [
      for (var i = 0; i < 7; i++)
        DateFormat.E().format(DateTime(2024, 1, 1 + i)).substring(0, 1),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onMonthChanged(-1),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(month.toLocalMidnight()),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onMonthChanged(1),
              ),
            ],
          ),
          Row(
            children: [
              for (final name in weekdayNames)
                Expanded(
                  child: Center(
                    child: Text(name, style: theme.textTheme.labelSmall),
                  ),
                ),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.25,
            children: [
              for (final day in cells)
                if (day == null)
                  const SizedBox.shrink()
                else
                  _DayCell(
                    day: day,
                    isSelected: day == selected,
                    isToday: day == today,
                    isBusy: busyDays.contains(day),
                    onTap: () => onSelect(day),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isBusy,
    required this.onTap,
  });

  final CalendarDate day;
  final bool isSelected;
  final bool isToday;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      // Read aloud as "16 October 2026, has appointments, selected".
      label:
          '${DateFormat.yMMMMd().format(day.toLocalMidnight())}'
          '${isBusy ? ', has appointments' : ''}',
      selected: isSelected,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? scheme.primary : null,
              border: isToday && !isSelected
                  ? Border.all(color: scheme.primary)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isSelected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
                if (isBusy)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? scheme.onPrimary : scheme.tertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// #enddocregion monthgrid
