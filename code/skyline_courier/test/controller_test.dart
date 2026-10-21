import 'package:flutter_test/flutter_test.dart';
import 'package:skyline_courier/audio/sounds.dart';
import 'package:skyline_courier/game/game_controller.dart';
import 'package:skyline_courier/game/high_score_store.dart';
import 'package:skyline_courier/game/world.dart';

import 'support/capture.dart';

class RecordingSounds implements GameSounds {
  final played = <SoundEffect>[];
  bool disposed = false;
  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);
  @override
  Future<void> dispose() async => disposed = true;
}

const frame = Duration(microseconds: 16667); // one 60 Hz frame

void main() {
  late World world;
  late MemoryHighScoreStore scores;
  late RecordingSounds sounds;
  late GameController game;

  setUp(() {
    world = World(seed: 3);
    scores = MemoryHighScoreStore(10);
    sounds = RecordingSounds();
    game = GameController(world: world, scores: scores, sounds: sounds);
  });
  tearDown(() => game.dispose());

  /// Plays [frames] frames, with no taps.
  void play(int frames) {
    for (var i = 0; i < frames; i++) {
      game.advance(frame);
    }
  }

  test('the game does not run until the first tap', () {
    play(60);
    expect(world.status, GameStatus.ready);
    expect(world.elapsed, 0);
    game.tap();
    expect(world.status, GameStatus.running);
    expect(sounds.played, [SoundEffect.flap]);
  });

  test('frames move the world, and notify listeners so the painter redraws', () {
    var notifications = 0;
    game.addListener(() => notifications++);
    game.tap();
    final before = notifications;
    play(30);
    expect(notifications - before, 30);
    expect(world.elapsed, closeTo(0.5, 0.05));
  });

  test('a crash plays the sound once and records the score exactly once', () async {
    game.tap();
    play(300); // falls to the ground
    await Future<void>.delayed(Duration.zero);
    expect(world.status, GameStatus.over);
    expect(sounds.played.where((s) => s == SoundEffect.crash), hasLength(1));
    expect(scores.best, 10, reason: 'a score of 0 does not beat the best of 10');
    expect(game.newRecord, isFalse);
    play(60); // more frames after the crash change nothing
    game.tap();
    expect(sounds.played.where((s) => s == SoundEffect.crash), hasLength(1));
  });

  test('a score above the best is saved and reported as a record', () async {
    scores.best = 0;
    game.tap();
    world.parcels
      ..clear()
      ..add(Parcel(x: Tuning.courierX, y: world.courierY));
    game.advance(frame);
    expect(sounds.played, contains(SoundEffect.pickup));
    play(300);
    await Future<void>.delayed(Duration.zero);
    expect(world.score, Tuning.pointsPerParcel);
    expect(scores.best, Tuning.pointsPerParcel);
    expect(game.newRecord, isTrue);
    expect(game.best, Tuning.pointsPerParcel);
  });

  test('pausing freezes the game, and time spent paused is not caught up', () {
    game.tap();
    play(30);
    final elapsed = world.elapsed;
    game.pause();
    expect(game.paused, isTrue);
    play(600); // ten seconds of frames while paused
    game.tap(); // taps are ignored too
    expect(world.elapsed, elapsed);
    game.resume();
    game.advance(const Duration(seconds: 5)); // one huge frame right after resuming
    expect(world.elapsed - elapsed, lessThan(0.1), reason: 'at most five steps, not five seconds');
    writeCaptured(
      'sk_pause.txt',
      'game time before pausing:                ${elapsed.toStringAsFixed(2)} s\n'
          'after 10 s of frames while paused:       ${elapsed.toStringAsFixed(2)} s (unchanged)\n'
          'after resuming and one 5-second frame:   ${world.elapsed.toStringAsFixed(2)} s',
    );
  });

  test('pause does nothing when the game is not running', () {
    game.pause();
    expect(game.paused, isFalse);
    game.tap();
    play(300);
    expect(world.status, GameStatus.over);
    game.pause();
    expect(game.paused, isFalse);
  });

  test('restart gives a fresh game', () async {
    game.tap();
    play(300);
    await Future<void>.delayed(Duration.zero);
    game.restart();
    expect(world.status, GameStatus.ready);
    expect(world.score, 0);
    expect(game.newRecord, isFalse);
    game.tap();
    expect(world.status, GameStatus.running);
  });

  test('disposing the controller releases the sounds', () {
    game.dispose();
    expect(sounds.disposed, isTrue);
    // tearDown disposes a second time; ChangeNotifier allows no further use, so
    // build a fresh one for it.
    game = GameController(world: world, scores: scores, sounds: const SilentSounds());
  });
}
