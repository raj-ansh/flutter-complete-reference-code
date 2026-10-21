// #docregion extends
class Animal {
  Animal(this.name);

  final String name;

  String sound() => '...';

  void speak() => print('$name says ${sound()}');
}

class Dog extends Animal {
  Dog(super.name);

  @override
  String sound() => 'Woof';

  void fetch() => print('$name fetches the ball');
}

class Cat extends Animal {
  Cat(super.name);

  @override
  String sound() => 'Meow';

  @override
  void speak() {
    super.speak(); // call the parent version first
    print('$name purrs');
  }
}
// #enddocregion extends

// #docregion abstract
abstract class Shape {
  double get area; // no body: subclasses must provide it

  // Concrete members may use abstract ones.
  void describe() =>
      print('${runtimeType} with area ${area.toStringAsFixed(2)}');
}

class Rectangle extends Shape {
  Rectangle(this.width, this.height);
  final double width;
  final double height;

  @override
  double get area => width * height;
}

class Circle extends Shape {
  Circle(this.radius);
  final double radius;

  @override
  double get area => 3.14159265 * radius * radius;
}
// #enddocregion abstract

// #docregion interface
// Every class defines an implicit interface. "implements" promises to
// provide all of its members, with no inherited code.
abstract class Payable {
  double pay();
}

abstract class Reportable {
  String report();
}

class Employee implements Payable, Reportable {
  Employee(this.name, this.salary);
  final String name;
  final double salary;

  @override
  double pay() => salary / 12;

  @override
  String report() => '$name earns $salary a year';
}
// #enddocregion interface

// #docregion mixin
mixin Flying {
  bool airborne = false;
  void takeOff() {
    airborne = true;
    print('taking off');
  }
}

mixin Swimming {
  void swim() => print('swimming');
}

class Duck extends Animal with Flying, Swimming {
  Duck(super.name);

  @override
  String sound() => 'Quack';
}
// #enddocregion mixin

// Can this Animal fly?
bool isFlyer(Animal a) => a is Flying;

// Can this Payable also produce a report?
bool canReport(Payable p) => p is Reportable;

// #docregion run
void main() {
  var pets = <Animal>[Dog('Rex'), Cat('Tom'), Animal('Thing')];
  for (var pet in pets) {
    pet.speak();
  }
  var dog = pets.first;
  if (dog is Dog) {
    dog.fetch(); // promoted to Dog
  }

  var shapes = <Shape>[Rectangle(3, 4), Circle(1)];
  for (var s in shapes) {
    s.describe();
  }

  var e = Employee('Ada', 60000);
  print(e.report());
  print(e.pay());
  print(canReport(e));

  var duck = Duck('Donald');
  duck.speak();
  duck.takeOff();
  duck.swim();
  print(duck.airborne);
  print(isFlyer(duck));
  print(isFlyer(Dog('Rex')));
}
// #enddocregion run
