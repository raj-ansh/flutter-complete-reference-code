import 'package:flutter/widgets.dart';

/// How many times [ColorLabel.build] has run.
int colorLabelBuilds = 0;

// #docregion scope
/// Makes a color available to every widget below it in the tree.
class ColorScope extends InheritedWidget {
  const ColorScope({super.key, required this.color, required super.child});

  final Color color;

  /// Finds the nearest ColorScope above [context] and registers [context]
  /// as a dependent, so it rebuilds whenever the scope notifies.
  static ColorScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ColorScope>();
    assert(scope != null, 'No ColorScope found above this context.');
    return scope!;
  }

  /// Tell dependents to rebuild only when the color really changed.
  @override
  bool updateShouldNotify(ColorScope oldWidget) => color != oldWidget.color;
}

class ColorLabel extends StatelessWidget {
  const ColorLabel({super.key});

  @override
  Widget build(BuildContext context) {
    colorLabelBuilds++;
    final color = ColorScope.of(context).color;
    return Text('color: ${color.toARGB32().toRadixString(16)}');
  }
}
// #enddocregion scope
