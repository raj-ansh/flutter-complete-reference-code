import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'world.dart';

// #docregion painter
/// Draws the whole scene, in world units, onto a canvas the screen has already
/// scaled to fit. Every picture is made from rectangles, circles and rounded
/// shapes: no image files, so nothing to license and nothing to load.
class GamePainter extends CustomPainter {
  /// `repaint: controller` is the important part: the canvas is redrawn every
  /// time the controller notifies, without Flutter rebuilding any widgets.
  GamePainter(this.controller) : super(repaint: controller);

  final GameController controller;
  World get world => controller.world;

  // Paint objects are made once, not once per frame: creating objects 60 times
  // a second only gives the garbage collector work to do.
  final _sky = Paint()
    ..shader = ui.Gradient.linear(
      Offset.zero,
      const Offset(0, Tuning.height),
      const [Color(0xFF16213E), Color(0xFF3A4F8A), Color(0xFFE9967A)],
      const [0.0, 0.62, 1.0],
    );
  final _far = Paint()..color = const Color(0xFF2B3A67);
  final _near = Paint()..color = const Color(0xFF1B2545);
  final _window = Paint()..color = const Color(0xFFFFD580);
  final _tower = Paint()..color = const Color(0xFF53607F);
  final _towerCap = Paint()..color = const Color(0xFF3E4A66);
  final _ground = Paint()..color = const Color(0xFF111827);
  final _groundLine = Paint()
    ..color = const Color(0xFF374151)
    ..strokeWidth = 2;
  final _suit = Paint()..color = const Color(0xFFF59E0B);
  final _helmet = Paint()..color = const Color(0xFFFEF3C7);
  final _visor = Paint()..color = const Color(0xFF1F2937);
  final _box = Paint()..color = const Color(0xFFB45309);
  final _ribbon = Paint()..color = const Color(0xFFFCD34D);
  final _flameOuter = Paint()..color = const Color(0xFFEF4444);
  final _flameInner = Paint()..color = const Color(0xFFFDE68A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _sky);
    _skyline(canvas, factor: 0.18, paint: _far, minHeight: 120, maxHeight: 280, seed: 3);
    _skyline(canvas, factor: 0.42, paint: _near, minHeight: 70, maxHeight: 200, seed: 11);
    for (final t in world.towers) {
      _drawTower(canvas, t);
    }
    for (final p in world.parcels) {
      if (!p.collected) _drawParcel(canvas, p.x, p.y, Tuning.parcelRadius);
    }
    _drawGround(canvas);
    _drawCourier(canvas);
  }

  // #docregion skyline
  /// A band of buildings that scroll at [factor] times the speed of the towers.
  /// Slower layers look farther away (parallax). Each building's size comes
  /// from a hash of its index, so the same index always gives the same building
  /// and nothing needs to be stored or generated as the city scrolls.
  void _skyline(
    Canvas canvas, {
    required double factor,
    required Paint paint,
    required double minHeight,
    required double maxHeight,
    required int seed,
  }) {
    final offset = world.distance * factor;
    const slot = 64.0; // each building lives in a slot this wide
    final first = (offset / slot).floor();
    for (var i = first; i * slot - offset < Tuning.width + slot; i++) {
      final h = _hash(i, seed);
      final width = 36 + (h % 24);
      final height = minHeight + (h ~/ 7 % 1000) / 1000 * (maxHeight - minHeight);
      final left = i * slot - offset;
      final top = world.groundY - height;
      canvas.drawRect(Rect.fromLTWH(left, top, width.toDouble(), height), paint);
      // A few lit windows, chosen by the same hash.
      for (var row = 0; row < height ~/ 26; row++) {
        for (var col = 0; col < width ~/ 14; col++) {
          if (_hash(i * 31 + row * 7 + col, seed + 5) % 5 == 0) {
            canvas.drawRect(Rect.fromLTWH(left + 6 + col * 12, top + 8 + row * 24, 5, 8), _window);
          }
        }
      }
    }
  }

  /// A cheap, repeatable scramble of an integer: same input, same output.
  static int _hash(int n, int seed) {
    var x = (n * 374761393 + seed * 668265263) & 0x7fffffff;
    x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
    return (x ^ (x >> 16)) & 0x7fffffff;
  }
  // #enddocregion skyline

  void _drawTower(Canvas canvas, Tower t) {
    final topRect = Rect.fromLTRB(t.x, 0, t.right, t.gapTop);
    final bottomRect = Rect.fromLTRB(t.x, t.gapBottom, t.right, world.groundY);
    canvas.drawRect(topRect, _tower);
    canvas.drawRect(bottomRect, _tower);
    // Caps at the edges of the opening make the opening easy to read.
    canvas.drawRect(Rect.fromLTRB(t.x - 4, t.gapTop - 14, t.right + 4, t.gapTop), _towerCap);
    canvas.drawRect(Rect.fromLTRB(t.x - 4, t.gapBottom, t.right + 4, t.gapBottom + 14), _towerCap);
  }

  void _drawParcel(Canvas canvas, double x, double y, double r) {
    final rect = Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 2);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), _box);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 4, height: r * 2), _ribbon);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: r * 2, height: 4), _ribbon);
  }

  void _drawGround(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTRB(0, world.groundY, Tuning.width, Tuning.height),
      _ground,
    );
    final scroll = (world.distance % 40);
    for (var x = -scroll; x < Tuning.width; x += 40) {
      canvas.drawLine(Offset(x, world.groundY + 16), Offset(x + 20, world.groundY + 16), _groundLine);
    }
  }

  // #docregion courier
  void _drawCourier(Canvas canvas) {
    canvas.save();
    canvas.translate(Tuning.courierX, world.courierY);
    // Nose up when rising, nose down when falling.
    canvas.rotate((world.courierVy / 700).clamp(-0.45, 0.8));
    if (world.courierVy < 0 || world.status == GameStatus.ready) {
      final flicker = 8 + 5 * sin(world.elapsed * 60);
      canvas.drawOval(Rect.fromCenter(center: Offset(-14, 6), width: 10, height: flicker * 2), _flameOuter);
      canvas.drawOval(Rect.fromCenter(center: Offset(-14, 6), width: 5, height: flicker), _flameInner);
    }
    _drawParcel(canvas, -10, 0, 7); // the parcel on the courier's back
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 28, height: 24), _suit);
    canvas.drawCircle(const Offset(6, -8), 8, _helmet);
    canvas.drawOval(Rect.fromCenter(center: const Offset(9, -8), width: 8, height: 6), _visor);
    canvas.restore();
  }
  // #enddocregion courier

  @override
  bool shouldRepaint(GamePainter oldDelegate) => oldDelegate.controller != controller;
}
// #enddocregion painter
