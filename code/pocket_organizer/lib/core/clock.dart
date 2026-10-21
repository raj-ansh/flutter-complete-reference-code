// #docregion clock
/// The only place the app asks what time it is. Tests supply their own.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
// #enddocregion clock
