import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

// #docregion failure
/// Why a request failed. Callers react differently to each case: retry a
/// timeout, ask the user to sign in again, show "offline" for no connection.
sealed class ApiFailure {
  const ApiFailure();

  /// Is trying the same request again likely to help?
  bool get retryable;
  String get message;
}

final class NoConnection extends ApiFailure {
  const NoConnection();
  @override
  bool get retryable => true;
  @override
  String get message => 'No connection. Check your network and try again.';
}

final class RequestTimeout extends ApiFailure {
  const RequestTimeout();
  @override
  bool get retryable => true;
  @override
  String get message => 'The server took too long to answer.';
}

final class Unauthorized extends ApiFailure {
  const Unauthorized();
  @override
  bool get retryable => false;
  @override
  String get message => 'Please sign in again.';
}

final class NotFound extends ApiFailure {
  const NotFound();
  @override
  bool get retryable => false;
  @override
  String get message => 'That item no longer exists.';
}

final class ServerFailure extends ApiFailure {
  const ServerFailure(this.status);
  final int status;

  // 5xx and 429 can be temporary; other 4xx will fail the same way again.
  @override
  bool get retryable => status >= 500 || status == 429;
  @override
  String get message => 'The server had a problem (status $status).';
}

final class BadResponse extends ApiFailure {
  const BadResponse(this.detail);
  final String detail;
  @override
  bool get retryable => false;
  @override
  String get message => 'The server sent data the app could not read.';
}

/// Like Chapter 18's Result, but the failure is a type, not just a message.
sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiOk<T> extends ApiResult<T> {
  const ApiOk(this.value);
  final T value;
}

final class ApiErr<T> extends ApiResult<T> {
  const ApiErr(this.failure);
  final ApiFailure failure;
}
// #enddocregion failure

// #docregion classify
/// Turns whatever went wrong into an [ApiFailure].
ApiFailure classify(Object error) => switch (error) {
  TimeoutException() => const RequestTimeout(),
  SocketException() => const NoConnection(),
  http.ClientException() => const NoConnection(),
  FormatException(:final message) => BadResponse(message),
  _ => BadResponse('Unexpected error: $error'),
};
// #enddocregion classify
