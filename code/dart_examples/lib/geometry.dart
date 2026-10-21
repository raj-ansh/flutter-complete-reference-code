// A small library, used to demonstrate imports and exports.
import 'dart:math' as math;

// #docregion lib
/// A point in a plane.
class Vec {
  const Vec(this.x, this.y);
  final double x;
  final double y;

  Vec operator +(Vec o) => Vec(x + o.x, y + o.y);

  @override
  String toString() => 'Vec($x, $y)';
}

/// The distance between two points.
double distance(Vec a, Vec b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

// Names that start with an underscore are private to this library.
double _secret = 42;

/// Reads the private value; other files cannot touch [_secret] directly.
double revealSecret() => _secret;
// #enddocregion lib
