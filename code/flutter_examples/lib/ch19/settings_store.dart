import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// #docregion settings
/// Small user preferences in key-value storage. The allow-list names every
/// key this class may touch, so unrelated keys are never read or cleared.
class SettingsStore {
  SettingsStore._(this._prefs);

  static const _themeKey = 'settings.themeMode';
  static const _sortKey = 'settings.newestFirst';
  static const _launchesKey = 'settings.launchCount';

  final SharedPreferencesWithCache _prefs;

  static Future<SettingsStore> open() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_themeKey, _sortKey, _launchesKey},
      ),
    );
    return SettingsStore._(prefs);
  }

  /// Stored as the enum's name, so reordering the enum cannot corrupt it, and
  /// an unknown or missing value falls back to a default.
  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == _prefs.getString(_themeKey),
    orElse: () => ThemeMode.system,
  );

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeKey, mode.name);

  bool get newestFirst => _prefs.getBool(_sortKey) ?? true;

  Future<void> setNewestFirst(bool value) => _prefs.setBool(_sortKey, value);

  int get launchCount => _prefs.getInt(_launchesKey) ?? 0;

  Future<void> recordLaunch() => _prefs.setInt(_launchesKey, launchCount + 1);
}
// #enddocregion settings
