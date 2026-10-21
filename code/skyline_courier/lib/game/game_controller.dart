import 'package:flutter/foundation.dart';

import '../audio/sounds.dart';
import 'fixed_stepper.dart';
import 'high_score_store.dart';
import 'world.dart';

// #docregion controller
/// Connects the rules ([World]) to the outside: it receives frames and taps,
/// plays sounds, saves the best score, and tells the screen to redraw.
class GameController extends ChangeNotifier {
  GameController({
    required this.world,
    required this.scores,
    required this.sounds,
    FixedStepper? stepper,
  }) : _stepper = stepper ?? FixedStepper(),
       best = scores.best;

  final World world;
  final HighScoreStore scores;
  final GameSounds sounds;
  final FixedStepper _stepper;

  bool paused = false;
  bool newRecord = false;
  int best;
  bool _disposed = false;

  /// Steps the world forward by one frame's worth of real time.
  void advance(Duration frameTime) {
    if (paused || world.status != GameStatus.running) return;
    final seconds = frameTime.inMicroseconds / Duration.microsecondsPerSecond;
    final steps = _stepper.advance(seconds);
    for (var i = 0; i < steps && world.status == GameStatus.running; i++) {
      _react(world.step(_stepper.step));
    }
    notifyListeners(); // the painter repaints; no widget needs rebuilding
  }

  void tap() {
    if (paused) return;
    _react(world.flap());
    notifyListeners();
  }

  void pause() {
    if (paused || world.status != GameStatus.running) return;
    paused = true;
    notifyListeners();
  }

  void resume() {
    if (!paused) return;
    paused = false;
    _stepper.reset(); // time spent paused must not be "caught up"
    notifyListeners();
  }

  void restart() {
    world.reset();
    paused = false;
    newRecord = false;
    _stepper.reset();
    notifyListeners();
  }

  void _react(List<GameEvent> events) {
    for (final event in events) {
      switch (event) {
        case Flapped():
          sounds.play(SoundEffect.flap);
        case ParcelCollected():
          sounds.play(SoundEffect.pickup);
        case TowerPassed():
          break; // scored silently
        case Crashed():
          sounds.play(SoundEffect.crash);
          _recordScore();
      }
    }
  }

  Future<void> _recordScore() async {
    final score = world.score;
    final record = await scores.submit(score);
    // Saving takes a moment. If the player has already left the screen, the
    // controller is gone and there is nobody to tell.
    if (_disposed) return;
    newRecord = record;
    best = scores.best;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    sounds.dispose();
    super.dispose();
  }
}
// #enddocregion controller
