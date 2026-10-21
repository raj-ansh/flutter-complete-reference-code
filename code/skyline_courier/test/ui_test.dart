import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyline_courier/audio/sounds.dart';
import 'package:skyline_courier/game/game_controller.dart';
import 'package:skyline_courier/game/game_painter.dart';
import 'package:skyline_courier/game/high_score_store.dart';
import 'package:skyline_courier/game/world.dart';
import 'package:skyline_courier/main.dart';
import 'package:skyline_courier/ui/game_screen.dart';

import 'support/capture.dart';
import 'support/screenshot.dart';

GameController newGame({int seed = 7, int best = 0}) => GameController(
  world: World(seed: seed),
  scores: MemoryHighScoreStore(best),
  sounds: const SilentSounds(),
);

Widget screenFor(GameController c) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.amber, brightness: Brightness.dark)),
  home: GameScreen(controller: c),
);

/// Plays the world with the simple bot from the world tests, without a screen.
void flyBot(GameController c, double seconds) {
  final w = c.world;
  if (w.status == GameStatus.ready) c.tap();
  for (var i = 0; i < seconds * 60 && w.status == GameStatus.running; i++) {
    final ahead = w.towers.where((t) => t.right > Tuning.courierX - Tuning.courierRadius).toList();
    if (ahead.isNotEmpty && w.courierY > ahead.first.gapCenter + 14 && w.courierVy > -60) w.flap();
    c.advance(const Duration(microseconds: 16667));
  }
}

void main() {
  testWidgets('menu, play, crash, try again, and the best score on the menu', (tester) async {
    final scores = MemoryHighScoreStore(4);
    await tester.pumpWidget(SkylineCourierApp(scores: scores, makeSounds: () => const SilentSounds()));
    expect(find.text('Skyline Courier'), findsOneWidget);
    expect(find.text('Best: 4'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to fly'), findsOneWidget);
    expect(find.text('0'), findsOneWidget); // the score

    await tester.tapAt(tester.getCenter(find.byType(GameScreen)));
    await tester.pump();
    expect(find.text('Tap to fly'), findsNothing);

    // Without further taps the courier falls to the rooftops.
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Crashed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Crashed'), findsNothing);
    expect(find.text('Tap to fly'), findsOneWidget);

    // From the "ready" screen there is no Menu button; the system back
    // gesture (simulated here) returns to the menu.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('a new best is saved and shown on the menu afterwards', (tester) async {
    final scores = MemoryHighScoreStore(0);
    await tester.pumpWidget(SkylineCourierApp(scores: scores, makeSounds: () => const SilentSounds()));
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    // Fly with taps at intervals for a while to score something, then crash.
    await tester.tapAt(tester.getCenter(find.byType(GameScreen)));
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Crashed'), findsOneWidget);
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Best: ${scores.best}'), findsOneWidget);
  });

  testWidgets('the pause button freezes the game and Resume continues it', (tester) async {
    final game = newGame();
    await tester.pumpWidget(screenFor(game));
    await tester.tapAt(tester.getCenter(find.byType(GameScreen)));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.world.status, GameStatus.running);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    final frozen = game.world.elapsed;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.world.elapsed, frozen);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.world.elapsed, greaterThan(frozen));
    expect(find.text('Paused'), findsNothing);
    // Let the game end so no ticker is left running.
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  testWidgets('sending the app to the background pauses the game', (tester) async {
    final game = newGame();
    await tester.pumpWidget(screenFor(game));
    await tester.tapAt(tester.getCenter(find.byType(GameScreen)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.paused, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(game.paused, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.paused, isTrue, reason: 'coming back does not restart the action by itself');
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  testWidgets('taps count inside the scaled playfield and not in the margin around it', (tester) async {
    tester.view.physicalSize = const Size(1600, 900); // a wide window: bars at the sides
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final game = newGame();
    await tester.pumpWidget(screenFor(game));

    await tester.tapAt(const Offset(5, 450)); // far left, in the margin
    await tester.pump();
    expect(game.world.status, GameStatus.ready);

    final centre = tester.getCenter(find.byType(GameScreen));
    await tester.tapAt(centre);
    await tester.pump();
    expect(game.world.status, GameStatus.running);
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  group('the painter', () {
    test('draws every kind of scene without error, and repaints only for a new controller', () {
      final rows = StringBuffer();
      var scenes = 0;
      for (var seed = 1; seed <= 40; seed++) {
        final game = newGame(seed: seed);
        final painter = GamePainter(game);
        void draw() {
          final recorder = ui.PictureRecorder();
          painter.paint(Canvas(recorder), const Size(Tuning.width, Tuning.height));
          recorder.endRecording().dispose();
          scenes++;
        }

        draw(); // ready
        flyBot(game, 2 + seed % 7);
        draw(); // mid-game
        flyBot(game, 300);
        draw(); // over
        game.dispose();
      }
      final game = newGame();
      final a = GamePainter(game);
      expect(a.shouldRepaint(GamePainter(game)), isFalse);
      expect(a.shouldRepaint(GamePainter(newGame())), isTrue);

      // A rough cost: how long recording one mid-game scene takes on this computer.
      final busy = newGame(seed: 5);
      flyBot(busy, 20);
      final painter = GamePainter(busy);
      final watch = Stopwatch()..start();
      const runs = 500;
      for (var i = 0; i < runs; i++) {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(Tuning.width, Tuning.height));
        recorder.endRecording().dispose();
      }
      final micros = watch.elapsedMicroseconds / runs;
      rows.writeln('$scenes scenes (ready, mid-game and over, 40 seeds) drawn without error');
      rows.writeln('recording one mid-game frame takes about ${micros.toStringAsFixed(0)} microseconds on this computer');
      rows.writeln('(a 60 Hz frame has 16,667 microseconds in total; this measures recording the drawing commands only, '
          'not the work of the graphics hardware, and not on a phone)');
      writeCaptured('sk_painter.txt', rows.toString());
      expect(scenes, 120);
    });
  });

  testWidgets('screens for the book', (tester) async {
    await saveScreenshot(
      tester,
      SkylineCourierApp(scores: MemoryHighScoreStore(37), makeSounds: () => const SilentSounds()),
      'sk_menu',
      size: const Size(360, 640),
    );

    Future<void> shot(String name, GameController game, {void Function()? prepare}) async {
      await saveScreenshot(
        tester,
        screenFor(game),
        name,
        size: const Size(360, 640),
        settle: false,
        beforeCapture: (t) async {
          prepare?.call();
          await t.pump(const Duration(milliseconds: 16));
        },
      );
    }

    await shot('sk_ready', newGame(seed: 4, best: 37));
    final flying = newGame(seed: 4, best: 37);
    await shot('sk_flying', flying, prepare: () => flyBot(flying, 14));
    final crashed = newGame(seed: 4, best: 37);
    await shot('sk_over', crashed, prepare: () {
      flyBot(crashed, 400);
    });
    final paused = newGame(seed: 4, best: 37);
    await shot('sk_paused', paused, prepare: () {
      flyBot(paused, 6);
      paused.pause();
    });
  });
}
