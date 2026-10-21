sealed class Shape {}

class Circle extends Shape {}

class Rect extends Shape {}

class Triangle extends Shape {}

String name(Shape s) => switch (s) {
  Circle() => 'circle',
  Rect() => 'rect',
};

extension type UserId(int value) {}

void loadUser(UserId id) {}

extension Shout on String {
  String get shout => toUpperCase();
}

enum Light { red, green }

void main() {
  loadUser(42);

  var l = Light.red;
  switch (l) {
    case Light.red:
      print('stop');
  }

  var (a, b) = (1, 2, 3);

  Object text = 'hello';
  print(text.shout);
}
