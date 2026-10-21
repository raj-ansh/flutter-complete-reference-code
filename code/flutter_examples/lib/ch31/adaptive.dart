import 'package:flutter/material.dart';

// #docregion breakpoint
/// Below this width the app uses a bottom bar; at or above it, a side rail.
/// Flutter's adaptive-design guidance uses 600 logical pixels in its example.
const double compactWidth = 600;
// #enddocregion breakpoint

class Destination {
  const Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}

const destinations = [
  Destination('Notes', Icons.note),
  Destination('Tasks', Icons.check_circle),
  Destination('Contacts', Icons.person),
];

// #docregion shell
/// Navigation that follows the room available to it. `LayoutBuilder` reports
/// the size of *this widget's* space, which is what matters when the widget is
/// not the whole screen (split view, a desktop window, a foldable).
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final body = Center(child: Text('${destinations[_index].label} page'));
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < compactWidth) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
// #enddocregion shell

// #docregion fragile
/// Breaks when text is enlarged: nothing in this row is allowed to shrink.
class FragileRow extends StatelessWidget {
  const FragileRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.event),
        SizedBox(width: 8),
        Text('Dentist appointment with a long title'),
        SizedBox(width: 8),
        Text('10:30'),
      ],
    );
  }
}
// #enddocregion fragile

// #docregion robust
/// The same row, written to survive large text: the title may wrap.
class RobustRow extends StatelessWidget {
  const RobustRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.event),
        SizedBox(width: 8),
        Expanded(child: Text('Dentist appointment with a long title')),
        SizedBox(width: 8),
        Text('10:30'),
      ],
    );
  }
}
// #enddocregion robust
