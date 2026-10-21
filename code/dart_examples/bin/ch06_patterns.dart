// #docregion model
sealed class Shape {}

class Circle extends Shape {
  Circle(this.radius);
  final double radius;
}

class Rect extends Shape {
  Rect(this.width, this.height);
  final double width;
  final double height;
}
// #enddocregion model

// #docregion switchexpr
// A switch expression returns a value; every case is an expression.
String grade(int score) => switch (score) {
  >= 90 => 'A',
  >= 80 => 'B',
  >= 70 => 'C',
  _ => 'F', // the wildcard catches everything else
};

double area(Shape shape) => switch (shape) {
  Circle(radius: final r) => 3.14159 * r * r,
  Rect(:final width, :final height) => width * height,
};
// #enddocregion switchexpr

// #docregion guards
String classify(Object? value) => switch (value) {
  null => 'nothing',
  0 => 'zero',
  int n when n < 0 => 'negative int',
  int() => 'positive int',
  String s when s.isEmpty => 'empty string',
  String s => 'string of ${s.length}',
  [] => 'empty list',
  [var only] => 'list with one item: $only',
  [var first, ..., var last] => 'list from $first to $last',
  {'type': String t} => 'map of type $t',
  (int a, int b) => 'pair summing to ${a + b}',
  _ => 'something else',
};
// #enddocregion guards

// #docregion run
void main() {
  print(grade(95));
  print(grade(72));
  print(grade(10));
  print(area(Circle(1)));
  print(area(Rect(2, 3)));

  for (final v in [
    null,
    0,
    -4,
    7,
    '',
    'hello',
    [],
    [1],
    [1, 2, 3],
    {'type': 'user'},
    (3, 4),
    2.5,
  ]) {
    print('${v.runtimeType}: ${classify(v)}');
  }

  // Destructuring in declarations.
  var [x, y, z] = [10, 20, 30];
  print(x + y + z);
  var {'name': name, 'age': age} = {'name': 'Ada', 'age': 36};
  print('$name is $age');
  final (first, second) = ('left', 'right');
  print('$first/$second');

  // if-case: test and bind in one step.
  Object? maybe = [1, 'two'];
  if (maybe case [int one, String two]) {
    print('matched $one and $two');
  }

  // Pattern in a for-in loop over map entries.
  var scores = {'ada': 90, 'alan': 75};
  for (var MapEntry(:key, :value) in scores.entries) {
    print('$key scored $value (${grade(value)})');
  }
}
// #enddocregion run
