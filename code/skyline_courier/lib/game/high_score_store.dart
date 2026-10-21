import 'package:shared_preferences/shared_preferences.dart';

// #docregion highscore
abstract interface class HighScoreStore {
  int get best;

  /// Remembers [score] if it beats the best. Returns true for a new record.
  Future<bool> submit(int score);
}

class PrefsHighScoreStore implements HighScoreStore {
  PrefsHighScoreStore._(this._prefs);

  static const _key = 'skyline.best';
  final SharedPreferencesWithCache _prefs;

  static Future<PrefsHighScoreStore> open() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: {_key}),
    );
    return PrefsHighScoreStore._(prefs);
  }

  @override
  int get best => _prefs.getInt(_key) ?? 0;

  @override
  Future<bool> submit(int score) async {
    if (score <= best) return false;
    await _prefs.setInt(_key, score);
    return true;
  }
}

/// Keeps the best score in memory (tests, and a fallback when storage fails).
class MemoryHighScoreStore implements HighScoreStore {
  MemoryHighScoreStore([this.best = 0]);

  @override
  int best;

  @override
  Future<bool> submit(int score) async {
    if (score <= best) return false;
    best = score;
    return true;
  }
}
// #enddocregion highscore
