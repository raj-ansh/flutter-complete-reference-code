// #docregion imports
// A built-in library, with a prefix to avoid name clashes.
import 'dart:math' as math;

// Import everything from a package library.
import 'package:dart_examples/geometry.dart';

// Import only one name.
import 'package:dart_examples/modifiers.dart' show Greeter;

// #enddocregion imports

// #docregion run
void main() {
  var a = const Vec(0, 0);
  var b = const Vec(3, 4);
  print(a + b);
  print(distance(a, b));
  print(math.sqrt(16));
  print(math.max(3, 9));
  print(revealSecret());
  // print(_secret); // error: private to geometry.dart
  print(Greeter().greet('library'));
}
// #enddocregion run
