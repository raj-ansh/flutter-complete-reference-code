int square(int n) => n * n;

int applyTwice(int Function(int) f, int value) => f(f(value));

String greet({required String name, int times = 1}) => name * times;

class Animal {
  void speak() {}
}

class Dog extends Animal {
  @override
  void speek() {}
}

abstract class Shape {
  double get area;
}

class Square extends Shape {}

void main() {
  applyTwice(square(3), 3);
  greet(times: 2);
  var s = Shape();
  square(1, 2);
}
