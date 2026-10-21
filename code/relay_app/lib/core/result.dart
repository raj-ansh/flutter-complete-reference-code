// #docregion result
/// The outcome of something that can fail in expected ways.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

/// [code] is machine-readable (the server's codes such as `forbidden` or
/// `not_found`, plus `network`, `timeout` and `bad_response` raised by this
/// app); [message] is written for the person using the app.
final class Err<T> extends Result<T> {
  const Err(this.code, this.message);
  final String code;
  final String message;

  bool get isNetwork => code == 'network' || code == 'timeout';
}
// #enddocregion result
