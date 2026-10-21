import 'dart:async';

import 'package:flutter/material.dart';

/// Counts how many Item widgets were created and how many were built.
class ItemCounters {
  static int constructed = 0;
  static int built = 0;
  static void reset() {
    constructed = 0;
    built = 0;
  }
}

// #docregion item
/// A one-line row. The counters let a test see what the list really builds.
class Item extends StatelessWidget {
  Item(this.index, {super.key}) {
    ItemCounters.constructed++; // not const: each creation is counted
  }

  final int index;

  @override
  Widget build(BuildContext context) {
    ItemCounters.built++;
    return SizedBox(height: 56, child: ListTile(title: Text('Item $index')));
  }
}
// #enddocregion item

// #docregion eagervslazy
/// Creates every Item widget up front, even though few are ever shown.
class EagerList extends StatelessWidget {
  const EagerList({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView(children: [for (var i = 0; i < count; i++) Item(i)]);
  }
}

/// Creates an Item only when the list needs to show it.
class LazyList extends StatelessWidget {
  const LazyList({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (context, index) => Item(index),
    );
  }
}
// #enddocregion eagervslazy

// #docregion separated
class Contact {
  const Contact(this.name, this.phone);
  final String name;
  final String phone;
}

const _contacts = [
  Contact('Ada Lovelace', '555-0101'),
  Contact('Alan Turing', '555-0102'),
  Contact('Grace Hopper', '555-0103'),
  Contact('Katherine Johnson', '555-0104'),
  Contact('Margaret Hamilton', '555-0105'),
];

/// ListView.separated draws a divider between items.
class ContactList extends StatelessWidget {
  const ContactList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: _contacts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ListTile(
          leading: CircleAvatar(child: Text(contact.name[0])),
          title: Text(contact.name),
          subtitle: Text(contact.phone),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        );
      },
    );
  }
}
// #enddocregion separated

// #docregion refresh
/// Pull down to reload.
class RefreshableList extends StatefulWidget {
  const RefreshableList({super.key});

  @override
  State<RefreshableList> createState() => _RefreshableListState();
}

class _RefreshableListState extends State<RefreshableList> {
  List<String> _items = ['Version 1 - first', 'Version 1 - second'];
  int _version = 1;

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 300)); // "network"
    if (!mounted) return;
    setState(() {
      _version++;
      _items = ['Version $_version - first', 'Version $_version - second'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      // The list must always be scrollable, or short lists cannot be pulled.
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [for (final item in _items) ListTile(title: Text(item))],
      ),
    );
  }
}
// #enddocregion refresh

// #docregion infinite
/// Loads another page of 20 items when the user nears the end.
class InfiniteList extends StatefulWidget {
  const InfiniteList({super.key});

  @override
  State<InfiniteList> createState() => _InfiniteListState();
}

class _InfiniteListState extends State<InfiniteList> {
  final _controller = ScrollController();
  final List<int> _items = List.generate(20, (i) => i);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _controller.position;
    final nearEnd = position.pixels > position.maxScrollExtent - 200;
    if (nearEnd && !_loading) _loadMore();
  }

  Future<void> _loadMore() async {
    _loading = true; // guard: do not start a second load meanwhile
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() {
      final start = _items.length;
      _items.addAll(List.generate(20, (i) => start + i));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      itemCount: _items.length,
      itemExtent: 56,
      itemBuilder: (context, i) => ListTile(title: Text('Row ${_items[i]}')),
    );
  }
}
// #enddocregion infinite

// #docregion reorder
/// Drag the handle to reorder.
class ReorderDemo extends StatefulWidget {
  const ReorderDemo({super.key});

  @override
  State<ReorderDemo> createState() => _ReorderDemoState();
}

class _ReorderDemoState extends State<ReorderDemo> {
  final List<String> items = ['Plan', 'Build', 'Test', 'Ship'];

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      onReorderItem: (oldIndex, newIndex) {
        setState(() => items.insert(newIndex, items.removeAt(oldIndex)));
      },
      children: [
        for (final item in items)
          // Every child needs a key so Flutter can track it while it moves.
          ListTile(key: ValueKey(item), title: Text(item)),
      ],
    );
  }
}
// #enddocregion reorder

// #docregion expansion
class ExpansionDemo extends StatelessWidget {
  const ExpansionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ExpansionTile(
          title: Text('Soil'),
          initiallyExpanded: true,
          children: [
            ListTile(title: Text('Loam')),
            ListTile(title: Text('Sand')),
          ],
        ),
        ExpansionTile(
          title: Text('Light'),
          children: [ListTile(title: Text('Full sun'))],
        ),
      ],
    );
  }
}
// #enddocregion expansion
