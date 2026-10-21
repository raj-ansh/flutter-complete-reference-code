import 'package:flutter/foundation.dart';

// #docregion item
/// One line of a shopping list. Immutable, so a change means a new object.
@immutable
class PantryItem {
  const PantryItem(this.name, {this.bought = false});

  final String name;
  final bool bought;

  PantryItem copyWith({String? name, bool? bought}) =>
      PantryItem(name ?? this.name, bought: bought ?? this.bought);
}
// #enddocregion item

// #docregion model
/// App state for the shopping list. It knows nothing about widgets.
class PantryModel extends ChangeNotifier {
  final List<PantryItem> _items = [];

  /// A read-only view: callers cannot change the list behind our back.
  List<PantryItem> get items => List.unmodifiable(_items);

  /// Derived data is computed, never stored twice.
  int get remaining => _items.where((i) => !i.bought).length;

  void add(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _items.add(PantryItem(clean));
    notifyListeners();
  }

  void toggle(int index) {
    _items[index] = _items[index].copyWith(bought: !_items[index].bought);
    notifyListeners();
  }

  void rename(int index, String name) {
    _items[index] = _items[index].copyWith(name: name);
    notifyListeners();
  }

  void remove(int index) {
    _items.removeAt(index);
    notifyListeners();
  }
}
// #enddocregion model

// #docregion forgetful
/// A deliberately BROKEN model, used to show the two classic mistakes:
/// it hands out its private list, and it forgets to call notifyListeners.
class ForgetfulPantryModel extends ChangeNotifier {
  final List<PantryItem> items = [];

  void add(String name) {
    items.add(PantryItem(name));
    // notifyListeners() is missing, so no widget is told to rebuild.
  }
}
// #enddocregion forgetful
