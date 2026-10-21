import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/result.dart';
import '../data/models.dart';
import '../data/relay_api.dart';
import '../data/relay_service.dart';
import '../data/session_store.dart';
import '../data/transport.dart';

// #docregion serverurl
/// Checks the address the user typed. Returns the cleaned address, or an error
/// message. Only http and https are accepted, and a host is required.
Result<Uri> parseServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return const Err('invalid', 'Enter the server address.');
  if (!text.contains('://')) text = 'http://$text'; // "10.0.2.2:3000" is fine
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    return const Err('invalid', 'That does not look like a server address.');
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return const Err('invalid', 'The address must start with http:// or https://.');
  }
  // Uri.tryParse is forgiving: "exa mple.com" parses, with the space turned
  // into %20. A host name has letters, digits, dots, dashes (and colons for
  // IPv6), so anything else is a typo.
  if (!RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(uri.host)) {
    return const Err('invalid', 'That does not look like a server address.');
  }
  // Keep scheme, host and port; drop any path, query or trailing slash.
  return Ok(Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null));
}
// #enddocregion serverurl

// #docregion sessionstate
sealed class SessionState {
  const SessionState();
}

/// Looking for a saved session at start-up.
final class Restoring extends SessionState {
  const Restoring();
}

final class SignedOut extends SessionState {
  const SignedOut({this.notice});

  /// Why the user is signed out, when it was not their choice.
  final String? notice;
}

final class SignedIn extends SessionState {
  const SignedIn(this.user);
  final User user;
}
// #enddocregion sessionstate

// #docregion sessionvm
class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required this.store,
    required this.client,
    required this.transport,
  }) : service = RelayService(transport) {
    _events = transport.events.listen(_onEvent);
  }

  final SessionStore store;
  final http.Client client;
  final RelayTransport transport;
  final RelayService service;
  late final StreamSubscription<TransportEvent> _events;

  SessionState _state = const Restoring();
  SessionState get state => _state;

  bool _online = false;

  /// Is the live connection up right now? (Signed in but offline is normal.)
  bool get online => _online;

  Uri? _baseUri;
  String? _token;
  bool _disposed = false;

  /// Called once at start-up: reconnect with the saved token, if any.
  Future<void> restore() async {
    final saved = await store.read();
    if (saved == null) return _set(const SignedOut());
    final parsed = parseServerUrl(saved.serverUrl);
    if (parsed is! Ok<Uri>) {
      await store.clear();
      return _set(const SignedOut());
    }
    // Signed in at once, even if the network is down: the connection keeps
    // trying, and the screens show an "offline" banner meanwhile.
    _baseUri = parsed.value;
    _token = saved.session.token;
    _set(SignedIn(saved.session.user));
    transport.connect(_baseUri!, _token!);
  }

  /// Signs in (or creates the account) and opens the live connection.
  Future<Result<void>> signIn({
    required String serverUrl,
    required String username,
    required String password,
    required bool createAccount,
  }) async {
    final parsed = parseServerUrl(serverUrl);
    if (parsed is Err<Uri>) return Err(parsed.code, parsed.message);
    final base = (parsed as Ok<Uri>).value;

    final api = RelayApi(client: client, baseUri: base);
    final result = createAccount
        ? await api.register(username, password)
        : await api.login(username, password);
    switch (result) {
      case Err(:final code, :final message):
        return Err(code, message);
      case Ok(:final value):
        await store.save(base.toString(), value);
        _baseUri = base;
        _token = value.token;
        _set(SignedIn(value.user));
        transport.connect(base, value.token);
        return const Ok(null);
    }
  }

  Future<void> signOut() async {
    final token = _token;
    final base = _baseUri;
    transport.disconnect();
    _online = false;
    _token = null;
    await store.clear();
    _set(const SignedOut());
    // Tell the server last, and never wait on it for the user's sake.
    if (token != null && base != null) {
      unawaited(RelayApi(client: client, baseUri: base).logout(token));
    }
  }

  Future<void> _onEvent(TransportEvent event) async {
    switch (event) {
      case Connected():
        _online = true;
        notifyListeners();
      case Disconnected():
        _online = false;
        notifyListeners();
      case ConnectFailed(unauthorized: true):
        await _forceSignOut('Your session has ended. Please sign in again.');
      case SessionExpired():
        await _forceSignOut('Your session has expired. Please sign in again.');
      default:
        break;
    }
  }

  Future<void> _forceSignOut(String notice) async {
    if (_state is! SignedIn) return;
    transport.disconnect();
    _online = false;
    _token = null;
    await store.clear();
    _set(SignedOut(notice: notice));
  }

  void _set(SessionState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events.cancel();
    transport.disconnect();
    super.dispose();
  }
}
// #enddocregion sessionvm
