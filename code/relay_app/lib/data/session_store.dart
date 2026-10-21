import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

// #docregion sessionstore
/// What is remembered between launches so the user need not sign in again.
class SavedSession {
  const SavedSession({required this.serverUrl, required this.session});
  final String serverUrl;
  final Session session;
}

/// Keeps the token in the platform's secure storage (Keychain on iOS, an
/// encrypted store on Android; see Chapter 19), never in plain preferences.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _url = 'relay.serverUrl';
  static const _token = 'relay.token';
  static const _userId = 'relay.userId';
  static const _username = 'relay.username';

  Future<SavedSession?> read() async {
    final url = await _storage.read(key: _url);
    final token = await _storage.read(key: _token);
    final id = await _storage.read(key: _userId);
    final name = await _storage.read(key: _username);
    if (url == null || token == null || id == null || name == null) return null;
    return SavedSession(
      serverUrl: url,
      session: Session(user: User(id: id, username: name), token: token),
    );
  }

  Future<void> save(String serverUrl, Session session) async {
    await _storage.write(key: _url, value: serverUrl);
    await _storage.write(key: _token, value: session.token);
    await _storage.write(key: _userId, value: session.user.id);
    await _storage.write(key: _username, value: session.user.username);
  }

  /// Forgets the account. The server address is kept: it is not a secret and
  /// the next sign-in should not make the user type it again.
  Future<void> clear() async {
    await _storage.delete(key: _token);
    await _storage.delete(key: _userId);
    await _storage.delete(key: _username);
  }

  Future<String?> lastServerUrl() => _storage.read(key: _url);
}
// #enddocregion sessionstore
