import 'package:flutter/services.dart';

// #docregion model
/// What the rest of the app sees: plain Dart, no channels, no exceptions.
sealed class BatteryReading {
  const BatteryReading();
}

class BatteryLevel extends BatteryReading {
  const BatteryLevel(this.percent);
  final int percent;
}

class BatteryUnavailable extends BatteryReading {
  const BatteryUnavailable(this.reason);
  final String reason;
}
// #enddocregion model

// #docregion channel
/// The Dart half of a platform channel. The native half (Kotlin, Swift, ...)
/// registers a handler under the same channel name and method name.
class BatteryChannel {
  BatteryChannel([MethodChannel? channel])
    : _channel =
          channel ?? const MethodChannel('dev.example.reference/battery');

  final MethodChannel _channel;

  Future<BatteryReading> read() async {
    try {
      final percent = await _channel.invokeMethod<int>('getBatteryLevel');
      if (percent == null || percent < 0 || percent > 100) {
        return const BatteryUnavailable(
          'The platform returned an unusable value',
        );
      }
      return BatteryLevel(percent);
    } on PlatformException catch (e) {
      // The native side answered with an error: code, message, details.
      return BatteryUnavailable(e.message ?? e.code);
    } on MissingPluginException {
      // Nothing is registered under this name (wrong platform, or a typo).
      return const BatteryUnavailable('Not supported on this platform');
    }
  }
}
// #enddocregion channel
