import 'dart:math';

// The game rules, in plain Dart with no Flutter in sight. Everything is in
// "world units": the playfield is always 360 wide and 640 high, whatever the
// phone's screen is, and the drawing code scales it. Because nothing here knows
// about pixels, time or the screen, the whole game can be tested by calling
// step() in a loop.

// #docregion constants
/// The size of the playfield and the tuning numbers. Changing a number changes
/// how the game feels; every other file refers to these.
abstract final class Tuning {
  static const width = 360.0;
  static const height = 640.0;
  static const groundHeight = 56.0; // the rooftop strip at the bottom
  static const courierX = 96.0;
  static const courierRadius = 14.0;

  static const gravity = 1100.0; // units per second, per second
  static const flapSpeed = 330.0; // upward speed after a tap
  static const maxFallSpeed = 560.0;

  static const towerWidth = 56.0;
  static const parcelRadius = 11.0;
  static const startSpeed = 120.0; // how fast the city scrolls at the start
  static const speedPerLevel = 8.0;
  static const secondsPerLevel = 10.0;
  static const maxLevel = 12;
  static const firstGap = 200.0; // vertical opening between a tower pair
  static const minGap = 140.0;
  static const gapShrinkPerLevel = 5.0;
  static const towerSpacingMin = 210.0;
  static const towerSpacingMax = 260.0;
  static const firstTowerX = 520.0;

  static const pointsPerTower = 1;
  static const pointsPerParcel = 5;
}
// #enddocregion constants

enum GameStatus { ready, running, over }

/// Things that happened during a step; the sound and the screen react to them.
sealed class GameEvent {
  const GameEvent();
}

final class Flapped extends GameEvent {
  const Flapped();
}

final class ParcelCollected extends GameEvent {
  const ParcelCollected();
}

final class TowerPassed extends GameEvent {
  const TowerPassed();
}

final class Crashed extends GameEvent {
  const Crashed(this.reason);
  final String reason; // 'tower', 'ground' or 'ceiling'
}

// #docregion shapes
/// A pair of towers with an opening between them. Only the opening is stored;
/// the towers are everything above and below it.
class Tower {
  Tower({required this.x, required this.gapTop, required this.gapHeight});

  double x; // left edge
  final double gapTop;
  final double gapHeight;
  bool passed = false;

  double get gapBottom => gapTop + gapHeight;
  double get right => x + Tuning.towerWidth;
  double get gapCenter => gapTop + gapHeight / 2;
}

class Parcel {
  Parcel({required this.x, required this.y});
  double x; // centre
  final double y;
  bool collected = false;
}
// #enddocregion shapes

/// How hard the game is after [elapsed] seconds of play.
class Difficulty {
  const Difficulty(this.level, this.speed, this.gap);

  factory Difficulty.at(double elapsed) {
    final level = min(Tuning.maxLevel, elapsed ~/ Tuning.secondsPerLevel);
    return Difficulty(
      level,
      Tuning.startSpeed + Tuning.speedPerLevel * level,
      max(Tuning.minGap, Tuning.firstGap - Tuning.gapShrinkPerLevel * level),
    );
  }

  final int level;
  final double speed;
  final double gap;
}

// #docregion collision
/// Does a circle touch a rectangle? Find the point of the rectangle nearest to
/// the circle's centre; they touch if that point is within the radius.
bool circleHitsRect(
  double cx,
  double cy,
  double r,
  double left,
  double top,
  double right,
  double bottom,
) {
  final nearestX = cx.clamp(left, right);
  final nearestY = cy.clamp(top, bottom);
  final dx = cx - nearestX;
  final dy = cy - nearestY;
  return dx * dx + dy * dy <= r * r;
}

bool circlesTouch(double ax, double ay, double ar, double bx, double by, double br) {
  final dx = ax - bx;
  final dy = ay - by;
  final reach = ar + br;
  return dx * dx + dy * dy <= reach * reach;
}
// #enddocregion collision

// #docregion world
class World {
  /// [seed] decides where towers and parcels appear, so a game can be replayed
  /// exactly (and tested) by using the same seed and the same taps.
  World({int seed = 1}) : _random = Random(seed) {
    reset();
  }

  final Random _random;

  GameStatus status = GameStatus.ready;
  double elapsed = 0; // seconds of play
  double courierY = 0;
  double courierVy = 0;
  int towersPassed = 0;
  int parcelsCollected = 0;
  final towers = <Tower>[];
  final parcels = <Parcel>[];

  /// Distance scrolled so far, which the background uses for parallax.
  double distance = 0;

  int get score =>
      towersPassed * Tuning.pointsPerTower +
      parcelsCollected * Tuning.pointsPerParcel;

  Difficulty get difficulty => Difficulty.at(elapsed);

  double get groundY => Tuning.height - Tuning.groundHeight;

  void reset() {
    status = GameStatus.ready;
    elapsed = 0;
    distance = 0;
    courierY = Tuning.height * 0.45;
    courierVy = 0;
    towersPassed = 0;
    parcelsCollected = 0;
    towers.clear();
    parcels.clear();
    _spawnAhead(Tuning.firstTowerX);
  }

  /// A tap. Starts the game if it was waiting; ignored once it is over.
  List<GameEvent> flap() {
    if (status == GameStatus.over) return const [];
    status = GameStatus.running;
    courierVy = -Tuning.flapSpeed;
    return const [Flapped()];
  }

  /// Advances the game by [dt] seconds (a small, fixed amount: see FixedStepper).
  List<GameEvent> step(double dt) {
    if (status != GameStatus.running) return const [];
    final events = <GameEvent>[];
    elapsed += dt;
    final speed = difficulty.speed;

    // The courier falls, and never faster than a terminal speed.
    courierVy = min(Tuning.maxFallSpeed, courierVy + Tuning.gravity * dt);
    courierY += courierVy * dt;

    // The city scrolls left.
    distance += speed * dt;
    for (final t in towers) {
      t.x -= speed * dt;
    }
    for (final p in parcels) {
      p.x -= speed * dt;
    }

    // Score a tower when its right edge goes behind the courier.
    for (final t in towers) {
      if (!t.passed && t.right < Tuning.courierX - Tuning.courierRadius) {
        t.passed = true;
        towersPassed += 1;
        events.add(const TowerPassed());
      }
    }
    for (final p in parcels) {
      if (!p.collected &&
          circlesTouch(Tuning.courierX, courierY, Tuning.courierRadius, p.x, p.y, Tuning.parcelRadius)) {
        p.collected = true;
        parcelsCollected += 1;
        events.add(const ParcelCollected());
      }
    }

    // Forget what has scrolled off the left; make more on the right.
    towers.removeWhere((t) => t.right < -10);
    parcels.removeWhere((p) => p.collected || p.x < -40);
    final farthest = towers.isEmpty ? Tuning.width : towers.last.x;
    if (farthest < Tuning.width + 40) {
      _spawnAhead(farthest + _spacing());
    }

    final crash = _crashReason();
    if (crash != null) {
      status = GameStatus.over;
      events.add(Crashed(crash));
    }
    return events;
  }

  String? _crashReason() {
    final r = Tuning.courierRadius;
    if (courierY + r >= groundY) return 'ground';
    if (courierY - r <= 0) return 'ceiling';
    for (final t in towers) {
      final hitsTop = circleHitsRect(Tuning.courierX, courierY, r, t.x, 0, t.right, t.gapTop);
      final hitsBottom = circleHitsRect(Tuning.courierX, courierY, r, t.x, t.gapBottom, t.right, groundY);
      if (hitsTop || hitsBottom) return 'tower';
    }
    return null;
  }

  double _spacing() =>
      Tuning.towerSpacingMin +
      _random.nextDouble() * (Tuning.towerSpacingMax - Tuning.towerSpacingMin);

  void _spawnAhead(double x) {
    final gap = difficulty.gap;
    const margin = 70.0; // keep the opening clear of the sky and the rooftops
    final lowest = groundY - margin - gap;
    final top = margin + _random.nextDouble() * (lowest - margin);
    towers.add(Tower(x: x, gapTop: top, gapHeight: gap));
    // A parcel hangs in the opening of about every other tower.
    if (_random.nextBool()) {
      parcels.add(Parcel(x: x + Tuning.towerWidth / 2, y: top + gap / 2));
    }
  }
}
// #enddocregion world
