import 'package:flutter/material.dart';

import 'pantry_model.dart';

/// Counts how many times each named widget's build method has run.
/// This is test instrumentation, not something an app needs.
final buildCounts = <String, int>{};
void countBuild(String name) => buildCounts[name] = (buildCounts[name] ?? 0) + 1;

// #docregion valuenotifier
/// A ValueNotifier holds one value and notifies when it is replaced.
class TemperaturePanel extends StatefulWidget {
  const TemperaturePanel({super.key});

  @override
  State<TemperaturePanel> createState() => _TemperaturePanelState();
}

class _TemperaturePanelState extends State<TemperaturePanel> {
  final _celsius = ValueNotifier<double>(20);

  @override
  void dispose() {
    _celsius.dispose(); // whoever creates a notifier must dispose it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    countBuild('panel');
    return Column(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _celsius,
          // The child is built once and reused on every rebuild.
          child: const Text('Room temperature'),
          builder: (context, value, child) {
            countBuild('reading');
            return Column(
              children: [child!, Text('${value.toStringAsFixed(1)} °C')],
            );
          },
        ),
        FilledButton(
          onPressed: () => _celsius.value += 0.5,
          child: const Text('Warmer'),
        ),
      ],
    );
  }
}
// #enddocregion valuenotifier

// #docregion listenable
/// A page that creates, owns and disposes a ChangeNotifier, and rebuilds
/// only the part that listens to it.
class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  final _model = PantryModel();
  final _field = TextEditingController();

  @override
  void dispose() {
    _model.dispose();
    _field.dispose();
    super.dispose();
  }

  void _add() {
    _model.add(_field.text);
    _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _field,
                  decoration: const InputDecoration(labelText: 'Item'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _add, child: const Text('Add')),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _model,
            builder: (context, _) {
              return Column(
                children: [
                  Text('${_model.remaining} left to buy'),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _model.items.length,
                      itemBuilder: (context, i) {
                        final item = _model.items[i];
                        return CheckboxListTile(
                          value: item.bought,
                          onChanged: (_) => _model.toggle(i),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              decoration: item.bought
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
// #enddocregion listenable

// #docregion scope
/// What the provider package does for you, written by hand: an
/// InheritedNotifier makes a model available to every descendant and rebuilds
/// the ones that looked it up.
class PantryScope extends InheritedNotifier<PantryModel> {
  const PantryScope({
    super.key,
    required PantryModel model,
    required super.child,
  }) : super(notifier: model);

  static PantryModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PantryScope>();
    assert(scope != null, 'No PantryScope above this context');
    return scope!.notifier!;
  }
}

class RemainingText extends StatelessWidget {
  const RemainingText({super.key});

  @override
  Widget build(BuildContext context) {
    // Looking the model up registers a dependency: this widget rebuilds
    // whenever the notifier fires.
    final model = PantryScope.of(context);
    return Text('${model.remaining} left to buy');
  }
}
// #enddocregion scope
