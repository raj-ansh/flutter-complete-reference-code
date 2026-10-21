import '../ch17/pantry_model.dart';

// #docregion result
/// The outcome of an operation that can fail, as a value instead of a throw.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.message);
  final String message;
}
// #enddocregion result

// #docregion service
/// Lowest layer: talks to one data source, holds no app logic.
abstract interface class PantryService {
  Future<List<PantryItem>> fetchAll();
  Future<void> saveAll(List<PantryItem> items);
}

/// A stand-in for a database or server, with controllable failure.
class InMemoryPantryService implements PantryService {
  InMemoryPantryService({
    List<PantryItem> initial = const [],
    this.latency = const Duration(milliseconds: 50),
  }) : _stored = List.of(initial);

  final Duration latency;
  List<PantryItem> _stored;
  int fetchCount = 0;
  bool failing = false;

  @override
  Future<List<PantryItem>> fetchAll() async {
    fetchCount++;
    await Future<void>.delayed(latency);
    if (failing) throw StateError('The pantry service is unreachable');
    return List.of(_stored);
  }

  @override
  Future<void> saveAll(List<PantryItem> items) async {
    await Future<void>.delayed(latency);
    if (failing) throw StateError('The pantry service is unreachable');
    _stored = List.of(items);
  }
}
// #enddocregion service

// #docregion repository
/// Middle layer: the single source of truth for pantry data. It caches,
/// turns exceptions into [Err] values, and returns domain objects.
class PantryRepository {
  PantryRepository(this._service);

  final PantryService _service;
  List<PantryItem>? _cache;

  Future<Result<List<PantryItem>>> load({bool refresh = false}) async {
    final cached = _cache;
    if (cached != null && !refresh) return Ok(List.unmodifiable(cached));
    try {
      final items = await _service.fetchAll();
      _cache = items;
      return Ok(List.unmodifiable(items));
    } on Object catch (e) {
      return Err('Could not load the list: $e');
    }
  }

  Future<Result<List<PantryItem>>> add(String name) =>
      _change((items) => [...items, PantryItem(name)]);

  Future<Result<List<PantryItem>>> toggle(int index) => _change(
    (items) => [
      for (var i = 0; i < items.length; i++)
        i == index ? items[i].copyWith(bought: !items[i].bought) : items[i],
    ],
  );

  /// Applies [change] to the current list and saves it. The cache is only
  /// replaced when saving succeeds, so a failure leaves the data unchanged.
  Future<Result<List<PantryItem>>> _change(
    List<PantryItem> Function(List<PantryItem>) change,
  ) async {
    final current = _cache;
    if (current == null) return const Err('The list is not loaded yet');
    final next = change(current);
    try {
      await _service.saveAll(next);
      _cache = next;
      return Ok(List.unmodifiable(next));
    } on Object catch (e) {
      return Err('Could not save the change: $e');
    }
  }
}
// #enddocregion repository
