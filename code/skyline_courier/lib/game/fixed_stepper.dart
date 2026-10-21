// #docregion stepper
/// Turns the irregular frames of a phone into regular simulation steps.
///
/// Frames arrive at 30, 60, 90, 120 or 144 per second, and sometimes late.
/// If the game moved "one step per frame" it would run faster on a fast
/// screen. Instead the game always advances in steps of exactly [step]
/// seconds, as many as the elapsed time calls for, so the same play produces
/// the same result on every device.
class FixedStepper {
  FixedStepper({this.step = 1 / 60, this.maxStepsPerFrame = 5});

  /// The size of one simulation step, in seconds.
  final double step;

  /// After a long pause (a slow frame, a debugger) do not try to catch up all
  /// at once: that makes the next frame even slower. Drop the excess instead.
  final int maxStepsPerFrame;

  double _accumulated = 0;

  /// Adds [dt] real seconds and returns how many simulation steps to run now.
  int advance(double dt) {
    _accumulated += dt;
    var steps = (_accumulated / step).floor();
    _accumulated -= steps * step;
    if (steps > maxStepsPerFrame) {
      steps = maxStepsPerFrame;
      _accumulated = 0; // the excess time is dropped, not saved up
    }
    return steps;
  }

  /// Forget time that has been collected but not yet used (after a pause).
  void reset() => _accumulated = 0;
}
// #enddocregion stepper
