import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notifier_demos.dart' show countBuild;
import 'pantry_model.dart';

// #docregion setup
/// ChangeNotifierProvider creates the model lazily, shares it with the
/// subtree, and disposes it when the provider leaves the tree.
class PantryApp extends StatelessWidget {
  const PantryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PantryModel()
        ..add('Milk')
        ..add('Bread')
        ..add('Basil'),
      child: const PantryScreen(),
    );
  }
}
// #enddocregion setup

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Text('Badge using select: '),
              SelectBadge(),
              SizedBox(width: 16),
              Text('using watch: '),
              WatchBadge(),
            ],
          ),
        ),
        Expanded(child: PantryList()),
        AddBar(),
      ],
    );
  }
}

// #docregion watch
/// context.watch rebuilds this widget whenever the model notifies.
class PantryList extends StatelessWidget {
  const PantryList({super.key});

  @override
  Widget build(BuildContext context) {
    countBuild('list');
    final items = context.watch<PantryModel>().items;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(items[i].name),
        leading: Checkbox(
          value: items[i].bought,
          // read: call a method once, do not subscribe to changes.
          onChanged: (_) => context.read<PantryModel>().toggle(i),
        ),
        onLongPress: () => context.read<PantryModel>().rename(i, 'Renamed'),
      ),
    );
  }
}
// #enddocregion watch

// #docregion select
/// context.select rebuilds only when the selected value changes.
class SelectBadge extends StatelessWidget {
  const SelectBadge({super.key});

  @override
  Widget build(BuildContext context) {
    countBuild('select badge');
    final remaining = context.select<PantryModel, int>((m) => m.remaining);
    return Badge(label: Text('$remaining'));
  }
}

class WatchBadge extends StatelessWidget {
  const WatchBadge({super.key});

  @override
  Widget build(BuildContext context) {
    countBuild('watch badge');
    final remaining = context.watch<PantryModel>().remaining;
    return Badge(label: Text('$remaining'));
  }
}
// #enddocregion select

/// Never subscribes: it only calls a method, so it never rebuilds.
class AddBar extends StatelessWidget {
  const AddBar({super.key});

  @override
  Widget build(BuildContext context) {
    countBuild('add bar');
    return Padding(
      padding: const EdgeInsets.all(12),
      child: FilledButton(
        onPressed: () => context.read<PantryModel>().add('Eggs'),
        child: const Text('Add eggs'),
      ),
    );
  }
}
