import 'package:flutter/services.dart';
import 'package:flutter_examples/ch30/battery_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.example.reference/battery');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // #docregion mock
  void answerWith(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  // #enddocregion mock

  // #docregion tests
  test('a number from the platform becomes a BatteryLevel', () async {
    MethodCall? seen;
    answerWith((call) async {
      seen = call;
      return 87;
    });

    final reading = await BatteryChannel().read();

    expect(seen?.method, 'getBatteryLevel');
    expect((reading as BatteryLevel).percent, 87);
  });

  test('an error from the native side becomes BatteryUnavailable', () async {
    answerWith((call) async {
      throw PlatformException(code: 'UNAVAILABLE', message: 'No battery');
    });

    final reading = await BatteryChannel().read();

    expect((reading as BatteryUnavailable).reason, 'No battery');
  });

  test('a platform with no handler is reported, not thrown', () async {
    // No mock handler registered: the call finds nobody on the other side.
    final reading = await BatteryChannel().read();

    expect(
      (reading as BatteryUnavailable).reason,
      'Not supported on this platform',
    );
  });

  test('nonsense from the platform is refused', () async {
    answerWith((call) async => 250);

    final reading = await BatteryChannel().read();

    expect(reading, isA<BatteryUnavailable>());
  });
  // #enddocregion tests
}
