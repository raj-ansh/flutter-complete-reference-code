import 'package:flutter/foundation.dart';

import 'result.dart';

// #docregion liststate
/// What a list screen can be showing. Shared by every feature.
sealed class ListState<T> {
  const ListState();

  /// The same state with the items rearranged, for example into sections.
  ListState<R> mapItems<R>(List<R> Function(List<T> items) convert) =>
      switch (this) {
        ListLoading<T>() => ListLoading<R>(),
        ListLoaded<T>(:final items, :final query, :final message) =>
          ListLoaded<R>(convert(items), query: query, message: message),
        ListFailed<T>(:final message) => ListFailed<R>(message),
      };
}

final class ListLoading<T> extends ListState<T> {
  const ListLoading();
}

final class ListLoaded<T> extends ListState<T> {
  const ListLoaded(this.items, {this.query = '', this.message});
  final List<T> items;
  final String query;

  /// A problem with the last action; the list stays visible.
  final String? message;

  bool get isSearching => query.trim().isNotEmpty;
}

final class ListFailed<T> extends ListState<T> {
  const ListFailed(this.message);
  final String message;
}
// #enddocregion liststate

// #docregion base
/// The behavior every list-of-things screen needs: load, search, show a
/// failed action without hiding the list, ignore stale answers, and stop
/// touching listeners after dispose. Features add their own commands.
abstract class ListViewModel<T> extends ChangeNotifier {
  ListState<T> _state = const ListLoading();
  ListState<T> get state => _state;

  String _query = '';
  String get query => _query;
  bool _disposed = false;
  int _generation = 0;

  /// Asks the repository for the items matching [query].
  @protected
  Future<Result<List<T>>> fetch(String query);

  Future<void> load() async {
    _set(const ListLoading());
    await reload();
  }

  Future<void> search(String query) async {
    _query = query;
    await reload();
  }

  /// Fetches again. Only the newest request may update the screen, otherwise
  /// a slow answer to "ba" could overwrite the answer to "basil".
  @protected
  Future<void> reload() async {
    final generation = ++_generation;
    final result = await fetch(_query);
    if (generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _set(ListLoaded(value, query: _query));
      case Err(:final message):
        _set(ListFailed(message));
    }
  }

  /// After a command: reload on success; on failure keep the list and show
  /// the message.
  @protected
  Future<void> afterAction(Result<Object?> result) async {
    switch (result) {
      case Ok():
        await reload();
      case Err(:final message):
        final current = _state;
        _set(
          current is ListLoaded<T>
              ? ListLoaded(current.items, query: _query, message: message)
              : ListFailed<T>(message),
        );
    }
  }

  void _set(ListState<T> state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
// #enddocregion base
