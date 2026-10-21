import 'package:dart_examples/modifiers.dart';

class A extends Printer {}

class B implements Entity { // base class: cannot be implemented
  @override
  int get id => 1;
}

class C extends Token { // final class: cannot be extended
  C() : super('x');
}

class D implements Token { // final class: cannot be implemented
  @override
  String get value => 'x';
}

class E extends Storage {} // abstract interface class: cannot be extended

void main() {
  Storage(); // abstract: cannot be instantiated
}
