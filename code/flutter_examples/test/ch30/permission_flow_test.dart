import 'package:flutter_examples/ch30/permission_flow.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements PermissionGateway {
  _Fake(this.current, {this.afterRequest});
  PermissionState current;
  final PermissionState? afterRequest;
  int requests = 0;

  @override
  Future<PermissionState> status() async => current;

  @override
  Future<PermissionState> request() async {
    requests++;
    return current = afterRequest ?? current;
  }
}

void main() {
  test('already granted: no request is made', () async {
    final gateway = _Fake(PermissionState.granted);
    expect(await PermissionFlow(gateway).ensure(), isA<Allowed>());
    expect(gateway.requests, 0);
  });

  test('denied, then the user agrees', () async {
    final gateway = _Fake(
      PermissionState.denied,
      afterRequest: PermissionState.granted,
    );
    expect(await PermissionFlow(gateway).ensure(), isA<Allowed>());
    expect(gateway.requests, 1);
  });

  test(
    'denied, and the user says no again: explain and offer another try',
    () async {
      final gateway = _Fake(PermissionState.denied);
      expect(await PermissionFlow(gateway).ensure(), isA<AskAgain>());
    },
  );

  test('permanently denied: never ask, point to Settings', () async {
    final gateway = _Fake(PermissionState.permanentlyDenied);
    expect(await PermissionFlow(gateway).ensure(), isA<SendToSettings>());
    expect(gateway.requests, 0);
  });
}
