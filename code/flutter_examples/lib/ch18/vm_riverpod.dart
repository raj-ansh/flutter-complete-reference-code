import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ch17/pantry_model.dart';
import 'data.dart';
import 'pantry_view.dart';
import 'state.dart';

// #docregion providers
/// Dependency injection: a provider that must be overridden at the top.
final pantryRepositoryProvider = Provider<PantryRepository>(
  (ref) => throw UnimplementedError('Override pantryRepositoryProvider'),
);

class PantryException implements Exception {
  const PantryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The AsyncNotifier's state is an AsyncValue: loading, data or error.
class PantryNotifier extends AsyncNotifier<List<PantryItem>> {
  PantryRepository get _repo => ref.read(pantryRepositoryProvider);

  @override
  Future<List<PantryItem>> build() async => _unwrap(await _repo.load());

  Future<void> toggle(int index) async => _applyResult(await _repo.toggle(index));

  Future<void> addEggs() async => _applyResult(await _repo.add('Eggs'));

  void _applyResult(Result<List<PantryItem>> result) {
    switch (result) {
      case Ok(:final value):
        state = AsyncData(value);
      case Err(:final message):
        // Riverpod keeps the previous data attached to the new error state.
        state = AsyncError<List<PantryItem>>(
          PantryException(message),
          StackTrace.current,
        );
    }
  }

  List<PantryItem> _unwrap(Result<List<PantryItem>> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final message) => throw PantryException(message),
  };
}

final pantryProvider = AsyncNotifierProvider<PantryNotifier, List<PantryItem>>(
  PantryNotifier.new,
);
// #enddocregion providers

// #docregion screen
class RiverpodPantryScreen extends ConsumerWidget {
  const RiverpodPantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pantryProvider);
    final notifier = ref.read(pantryProvider.notifier);
    final PantryState state = switch (async) {
      AsyncValue(hasValue: true, :final value?) => PantryLoaded(
        value,
        message: async.hasError ? async.error.toString() : null,
      ),
      AsyncError(:final error) => PantryFailed(error.toString()),
      _ => const PantryLoading(),
    };
    return PantryView(
      state: state,
      onToggle: notifier.toggle,
      onAdd: notifier.addEggs,
      onRetry: () => ref.invalidate(pantryProvider),
    );
  }
}
// #enddocregion screen
