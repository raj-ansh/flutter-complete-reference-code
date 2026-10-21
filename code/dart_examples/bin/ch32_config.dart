// Chapter 32: build-time configuration with --dart-define.
// Run it three ways:
//   dart run bin/ch32_config.dart
//   dart run -DAPI_URL=https://staging.example.test -DFLAVOR=staging bin/ch32_config.dart
//   dart run -DENABLE_LOGGING=true bin/ch32_config.dart

// #docregion config
/// Values chosen when the app is built, not when it runs. In a Flutter build
/// the same names are set with `--dart-define=NAME=value`.
abstract final class BuildConfig {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'development');
  static const enableLogging = bool.fromEnvironment('ENABLE_LOGGING');
}
// #enddocregion config

void main() {
  print('flavor:         ${BuildConfig.flavor}');
  print('api url:        ${BuildConfig.apiUrl}');
  print('logging:        ${BuildConfig.enableLogging}');
}
