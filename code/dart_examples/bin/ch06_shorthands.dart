// Dot shorthands need a Dart SDK constraint of 3.10 or newer.

// #docregion types
enum Direction { north, south }

class Size {
  const Size(this.width, this.height);
  const Size.square(double side) : width = side, height = side;
  static const Size zero = Size(0, 0);

  final double width;
  final double height;

  @override
  String toString() => 'Size($width x $height)';
}

void face(Direction d) => print('facing ${d.name}');
Size defaultSize() => .square(10); // the return type provides the context
// #enddocregion types

// #docregion run
void main() {
  // The variable's type supplies the context, so the type name can be dropped.
  Direction d = .north;
  Size s = .zero;
  Size sq = .square(4);
  Size plain = .new(2, 3);
  print('$d $s $sq $plain');

  face(.south); // the parameter type supplies the context
  print(d == .north); // a comparison supplies the context too
  List<Direction> all = [.north, .south];
  print(all);
  print(defaultSize());

  // Without a known type there is nothing to infer from, so write it in full.
  var explicit = Direction.south;
  print(explicit);
}
// #enddocregion run
