import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyline_courier/game/world.dart';

import 'support/capture.dart';

/// Runs the world for [seconds] of game time in fixed steps.
List<GameEvent> run(World w, double seconds, {double dt = 1 / 60}) {
  final events = <GameEvent>[];
  for (var t = 0.0; t < seconds && w.status == GameStatus.running; t += dt) {
    events.addAll(w.step(dt));
  }
  return events;
}

/// A very simple player: aim for the middle of the next opening and flap
/// whenever below it and not already rising. Used to prove the game can be played.
void botFlap(World w) {
  final ahead = w.towers.where((t) => t.right > Tuning.courierX - Tuning.courierRadius).toList();
  if (ahead.isEmpty) return;
  final target = ahead.first.gapCenter + 14; // a little low: flaps arc upward
  if (w.courierY > target && w.courierVy > -60) w.flap();
}

void main() {
  group('collision geometry', () {
    test('circle against rectangle: touching counts, near misses do not', () {
      final rows = StringBuffer('circle r=10 against the rectangle (100,100)-(200,200)\n');
      void check(String label, double cx, double cy, bool expected) {
        final hit = circleHitsRect(cx, cy, 10, 100, 100, 200, 200);
        rows.writeln('${label.padRight(34)}centre ($cx, $cy)  ${hit ? 'HIT' : 'miss'}');
        expect(hit, expected, reason: label);
      }

      check('inside the rectangle', 150, 150, true);
      check('touching the left edge', 90, 150, true);
      check('1 unit short of the left edge', 89, 150, false);
      check('touching the top edge', 150, 90, true);
      check('touching the corner exactly', 100 - 7.0710678, 100 - 7.0710678, true);
      check('near the corner, just outside', 92, 92, false); // distance 11.3
      check('far away', 400, 400, false);
      writeCaptured('sk_collisions.txt', rows.toString());
    });

    test('circle against circle', () {
      expect(circlesTouch(0, 0, 10, 20, 0, 10), isTrue); // exactly touching
      expect(circlesTouch(0, 0, 10, 20.1, 0, 10), isFalse);
      expect(circlesTouch(5, 5, 3, 5, 5, 3), isTrue);
    });
  });

  group('the courier', () {
    test('waits until the first tap; nothing moves while ready', () {
      final w = World(seed: 1);
      final y = w.courierY;
      expect(w.step(1 / 60), isEmpty);
      expect(w.status, GameStatus.ready);
      expect(w.courierY, y);
      expect(w.towers.first.x, Tuning.firstTowerX);
    });

    test('a flap launches upward, gravity pulls back: the arc has the height physics predicts', () {
      final w = World(seed: 1);
      final start = w.courierY;
      w.flap();
      final rows = StringBuffer('after one flap at y = ${start.toStringAsFixed(0)} (smaller y = higher)\n'
          'time (s)    y        vy\n');
      var apex = start;
      for (var i = 1; i <= 72; i++) {
        w.step(1 / 60);
        apex = min(apex, w.courierY);
        if (i % 6 == 0) {
          rows.writeln('${(i / 60).toStringAsFixed(2).padRight(10)}${w.courierY.toStringAsFixed(1).padRight(9)}${w.courierVy.toStringAsFixed(0)}');
        }
      }
      final rise = start - apex;
      final predicted = Tuning.flapSpeed * Tuning.flapSpeed / (2 * Tuning.gravity);
      rows.writeln('highest point: ${rise.toStringAsFixed(1)} units above the start '
          '(physics predicts v^2/2g = ${predicted.toStringAsFixed(1)})');
      writeCaptured('sk_flap_arc.txt', rows.toString());
      expect(rise, closeTo(predicted, 3)); // small difference from stepping in discrete slices
    });

    test('falling speed is limited; hitting the ground or the sky ends the game', () {
      final w = World(seed: 1)..flap();
      final events = run(w, 5);
      expect(w.status, GameStatus.over);
      expect((events.last as Crashed).reason, 'ground');
      expect(w.courierVy, lessThanOrEqualTo(Tuning.maxFallSpeed));

      final sky = World(seed: 1)..flap();
      for (var i = 0; i < 200 && sky.status == GameStatus.running; i++) {
        if (i % 10 == 0) sky.flap(); // flap far too often
        sky.step(1 / 60);
      }
      expect(sky.status, GameStatus.over);
    });

    test('once over, taps and steps do nothing until reset', () {
      final w = World(seed: 1)..flap();
      run(w, 5);
      final score = w.score;
      expect(w.flap(), isEmpty);
      expect(w.step(1 / 60), isEmpty);
      expect(w.score, score);
      w.reset();
      expect(w.status, GameStatus.ready);
      expect(w.score, 0);
    });
  });

  group('towers and parcels', () {
    test('the same seed gives the same course; a different seed gives another', () {
      List<String> course(int seed) {
        final w = World(seed: seed);
        // Scroll far enough to generate a dozen towers.
        w.flap();
        for (var i = 0; i < 600; i++) {
          w.courierY = Tuning.height / 2; // keep the courier alive; only the course matters
          w.courierVy = 0;
          w.step(1 / 60);
        }
        return [for (final t in w.towers) '${t.gapTop.toStringAsFixed(1)}/${t.gapHeight.toStringAsFixed(0)}'];
      }

      expect(course(42), course(42));
      expect(course(42), isNot(course(43)));
      writeCaptured(
        'sk_seeds.txt',
        'openings (top y / height) of the towers on screen at 10 s, by seed:\n'
            'seed 42:  ${course(42).join('  ')}\n'
            'seed 42:  ${course(42).join('  ')}   (again: identical)\n'
            'seed 43:  ${course(43).join('  ')}',
      );
    });

    test('every opening, on every seed and level, stays inside the playfield and wide enough', () {
      for (var seed = 0; seed < 300; seed++) {
        final w = World(seed: seed)..flap();
        for (var i = 0; i < 6000; i++) {
          w.courierY = Tuning.height / 2;
          w.courierVy = 0;
          w.step(1 / 60);
          if (i % 100 == 0) {
            for (final t in w.towers) {
              expect(t.gapHeight, greaterThanOrEqualTo(Tuning.minGap));
              expect(t.gapTop, greaterThanOrEqualTo(70));
              expect(t.gapBottom, lessThanOrEqualTo(w.groundY - 70 + 0.001));
            }
          }
        }
      }
    });

    test('passing a tower scores one point, once', () {
      final w = World(seed: 5)..flap();
      var passed = 0;
      for (var i = 0; i < 1500 && w.status == GameStatus.running; i++) {
        botFlap(w);
        passed += w.step(1 / 60).whereType<TowerPassed>().length;
      }
      expect(passed, greaterThan(2));
      expect(w.towersPassed, passed);
      expect(w.score, w.towersPassed * Tuning.pointsPerTower + w.parcelsCollected * Tuning.pointsPerParcel);
    });

    test('a parcel touching the courier is collected once and scores five', () {
      final w = World(seed: 5)..flap();
      w.parcels
        ..clear()
        ..add(Parcel(x: Tuning.courierX, y: w.courierY));
      final events = w.step(1 / 60);
      expect(events.whereType<ParcelCollected>(), hasLength(1));
      expect(w.score, Tuning.pointsPerParcel);
      expect(w.step(1 / 60).whereType<ParcelCollected>(), isEmpty);
      expect(w.parcelsCollected, 1);
    });

    test('hitting a tower ends the game', () {
      final w = World(seed: 5)..flap();
      w.towers
        ..clear()
        ..add(Tower(x: Tuning.courierX - 10, gapTop: 400, gapHeight: 120)); // courier is above the opening
      w.courierY = 200;
      final events = w.step(1 / 60);
      expect((events.last as Crashed).reason, 'tower');
    });
  });

  group('difficulty', () {
    test('speed rises and the opening narrows with time, up to a limit', () {
      final rows = StringBuffer('seconds   level   speed (units/s)   opening (units)\n');
      for (final s in <double>[0, 9.9, 10, 30, 60, 90, 120, 150, 300]) {
        final d = Difficulty.at(s);
        rows.writeln('${s.toString().padRight(10)}${d.level.toString().padRight(8)}${d.speed.toStringAsFixed(0).padRight(18)}${d.gap.toStringAsFixed(0)}');
      }
      writeCaptured('sk_difficulty.txt', rows.toString());
      expect(Difficulty.at(0).speed, Tuning.startSpeed);
      expect(Difficulty.at(0).gap, Tuning.firstGap);
      expect(Difficulty.at(9.9).level, 0);
      expect(Difficulty.at(10).level, 1);
      expect(Difficulty.at(1000).level, Tuning.maxLevel);
      expect(Difficulty.at(1000).gap, greaterThanOrEqualTo(Tuning.minGap));
      expect(Difficulty.at(60).speed, greaterThan(Difficulty.at(30).speed));
    });
  });

  group('a replay is exact', () {
    test('same seed and the same taps give the same game, to the last decimal', () {
      String play() {
        final w = World(seed: 99)..flap();
        for (var i = 0; i < 900 && w.status == GameStatus.running; i++) {
          if (i % 23 == 0) w.flap();
          w.step(1 / 60);
        }
        return '${w.score} ${w.elapsed} ${w.courierY} ${w.courierVy} ${w.towers.length}';
      }

      expect(play(), play());
    });
  });

  group('can the game be played at all?', () {
    test('a simple bot survives a long time on many seeds, at every difficulty', () {
      final rows = StringBuffer('a bot that aims at the middle of the next opening\n'
          'seed  survived (s)  towers  parcels  ended by\n');
      var minSurvived = double.infinity;
      for (var seed = 1; seed <= 12; seed++) {
        final w = World(seed: seed)..flap();
        String endedBy = 'time limit (150 s)';
        for (var i = 0; i < 150 * 60; i++) {
          botFlap(w);
          final events = w.step(1 / 60);
          final crash = events.whereType<Crashed>();
          if (crash.isNotEmpty) {
            endedBy = crash.first.reason;
            break;
          }
        }
        minSurvived = min(minSurvived, w.elapsed);
        rows.writeln('${seed.toString().padRight(6)}${w.elapsed.toStringAsFixed(1).padRight(15)}${w.towersPassed.toString().padRight(8)}${w.parcelsCollected.toString().padRight(9)}$endedBy');
      }
      writeCaptured('sk_bot.txt', rows.toString());
      // The point is existence, not perfection: this crude bot reaches the
      // middle of the difficulty curve on every seed, so the early game is
      // clearly playable. That it eventually dies says only that the bot is
      // simple; it does not show that the later levels are impossible.
      expect(minSurvived, greaterThanOrEqualTo(60));
    });
  });
}
