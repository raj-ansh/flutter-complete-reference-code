// #docregion result
/// The outcome of an operation that can fail in expected ways.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.message);

  /// Written for the user to read, not a stack trace.
  final String message;
}
// #enddocregion result
