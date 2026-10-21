import 'package:flutter/material.dart';

// #docregion buttons
/// The Material 3 button family, enabled (top) and disabled (bottom).
class ButtonCatalog extends StatelessWidget {
  const ButtonCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    void tap() {}
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Text buttons'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(onPressed: tap, child: const Text('Elevated')),
              FilledButton(onPressed: tap, child: const Text('Filled')),
              FilledButton.tonal(onPressed: tap, child: const Text('Tonal')),
              OutlinedButton(onPressed: tap, child: const Text('Outlined')),
              TextButton(onPressed: tap, child: const Text('Text')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              ElevatedButton(onPressed: null, child: Text('Elevated')),
              FilledButton(onPressed: null, child: Text('Filled')),
              OutlinedButton(onPressed: null, child: Text('Outlined')),
              TextButton(onPressed: null, child: Text('Text')),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Icon buttons'),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(onPressed: tap, icon: const Icon(Icons.favorite)),
              IconButton.filled(
                onPressed: tap,
                icon: const Icon(Icons.favorite),
              ),
              IconButton.filledTonal(
                onPressed: tap,
                icon: const Icon(Icons.favorite),
              ),
              IconButton.outlined(
                onPressed: tap,
                icon: const Icon(Icons.favorite),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Buttons with icons'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: tap,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              OutlinedButton.icon(
                onPressed: tap,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Floating action buttons'),
          const SizedBox(height: 8),
          Row(
            children: [
              FloatingActionButton.small(
                onPressed: tap,
                child: const Icon(Icons.add),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                onPressed: tap,
                child: const Icon(Icons.add),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                onPressed: tap,
                icon: const Icon(Icons.edit),
                label: const Text('Compose'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// #enddocregion buttons

// #docregion segmented
enum View { day, week, month }

/// A SegmentedButton replaces the older ToggleButtons for a few choices.
class SegmentedDemo extends StatefulWidget {
  const SegmentedDemo({super.key});

  @override
  State<SegmentedDemo> createState() => _SegmentedDemoState();
}

class _SegmentedDemoState extends State<SegmentedDemo> {
  View _view = View.week;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<View>(
        segments: const [
          ButtonSegment(value: View.day, label: Text('Day')),
          ButtonSegment(value: View.week, label: Text('Week')),
          ButtonSegment(value: View.month, label: Text('Month')),
        ],
        selected: {_view},
        onSelectionChanged: (selection) =>
            setState(() => _view = selection.first),
      ),
    );
  }
}
// #enddocregion segmented

// #docregion components
/// Cards, list tiles, chips, a badge and a navigation bar.
class ComponentCatalog extends StatefulWidget {
  const ComponentCatalog({super.key});

  @override
  State<ComponentCatalog> createState() => _ComponentCatalogState();
}

class _ComponentCatalogState extends State<ComponentCatalog> {
  int _index = 0;
  bool _selected = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Components'),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.mail),
              title: Text('Elevated card'),
              subtitle: Text('Default Card'),
            ),
          ),
          const Card.filled(
            child: ListTile(
              leading: Icon(Icons.inbox),
              title: Text('Filled card'),
              subtitle: Text('Card.filled'),
            ),
          ),
          const Card.outlined(
            child: ListTile(
              leading: Icon(Icons.archive),
              title: Text('Outlined card'),
              subtitle: Text('Card.outlined'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(label: const Text('Action'), onPressed: () {}),
              FilterChip(
                label: const Text('Filter'),
                selected: _selected,
                onSelected: (v) => setState(() => _selected = v),
              ),
              const ChoiceChip(label: Text('Choice'), selected: false),
              InputChip(label: const Text('Input'), onDeleted: () {}),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          Row(
            children: [
              Badge(
                label: const Text('3'),
                child: const Icon(Icons.notifications, size: 32),
              ),
              const SizedBox(width: 24),
              const Badge(child: Icon(Icons.chat, size: 32)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
// #enddocregion components
