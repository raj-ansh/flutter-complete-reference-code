import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ch17/pantry_model.dart';
import 'data.dart';
import 'pantry_view.dart';
import 'state.dart';

// #docregion viewmodel
/// ChangeNotifier view model: holds the UI state and exposes commands.
class PantryViewModel extends ChangeNotifier {
  PantryViewModel(this._repository);

  final PantryRepository _repository;
  PantryState _state = const PantryLoading();
  PantryState get state => _state;
  bool _disposed = false;

  Future<void> load({bool refresh = false}) async {
    _state = const PantryLoading();
    notifyListeners();
    _apply(await _repository.load(refresh: refresh));
  }

  Future<void> toggle(int index) async =>
      _apply(await _repository.toggle(index));

  Future<void> addEggs() async => _apply(await _repository.add('Eggs'));

  void _apply(Result<List<PantryItem>> result) {
    if (_disposed) return; // the screen may have closed while we waited
    _state = stateFromResult(_state, result);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
// #enddocregion viewmodel

// #docregion screen
/// The app provides one repository; the view model is created from it.
class NotifierPantryScreen extends StatelessWidget {
  const NotifierPantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          PantryViewModel(context.read<PantryRepository>())..load(),
      child: Consumer<PantryViewModel>(
        builder: (context, vm, _) => PantryView(
          state: vm.state,
          onToggle: vm.toggle,
          onAdd: vm.addEggs,
          onRetry: () => vm.load(refresh: true),
        ),
      ),
    );
  }
}
// #enddocregion screen
