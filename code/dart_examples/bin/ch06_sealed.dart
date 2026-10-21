// #docregion result
// A result type: the call either succeeded or failed, and the compiler
// makes sure you handle both.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.message);
  final String message;
}
// #enddocregion result

// #docregion parse
Result<int> parseAge(String text) {
  final n = int.tryParse(text);
  if (n == null) return const Failure('Not a number');
  if (n < 0 || n > 150) return const Failure('Out of range');
  return Success(n);
}
// #enddocregion parse

// #docregion show
String show(Result<int> r) => switch (r) {
  Success(value: final v) => 'Age is $v',
  Failure(message: final m) => 'Problem: $m',
};
// #enddocregion show

// #docregion states
// A UI state modeled so that impossible combinations cannot exist.
sealed class LoadState {}

class Loading extends LoadState {}

class Loaded extends LoadState {
  Loaded(this.items);
  final List<String> items;
}

class LoadError extends LoadState {
  LoadError(this.reason);
  final String reason;
}

String render(LoadState s) => switch (s) {
  Loading() => 'spinner',
  Loaded(items: final i) when i.isEmpty => 'empty message',
  Loaded(items: final i) => 'list of ${i.length}',
  LoadError(reason: final r) => 'error: $r',
};
// #enddocregion states

void main() {
  for (final text in ['42', 'abc', '200']) {
    print(show(parseAge(text)));
  }
  print(render(Loading()));
  print(render(Loaded([])));
  print(render(Loaded(['a', 'b'])));
  print(render(LoadError('offline')));
}
