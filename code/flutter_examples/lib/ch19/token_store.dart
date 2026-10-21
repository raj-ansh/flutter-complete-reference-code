import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// #docregion token
/// Secrets (sign-in tokens, keys) go in the platform's secure storage, never
/// in shared preferences or a plain file.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth.token';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);

  Future<void> save(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}
// #enddocregion token
