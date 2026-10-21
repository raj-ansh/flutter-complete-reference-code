// Class modifiers (Dart 3). Each declaration shows one rule that applies
// to code in OTHER libraries (files) that use it.

// #docregion modifiers
/// Can be implemented but not extended outside this library.
interface class Printer {
  void printLine(String text) => print(text);
}

/// Can be extended but not implemented outside this library.
base class Entity {
  Entity(this.id);
  final int id;
}

/// Cannot be extended or implemented outside this library.
final class Token {
  const Token(this.value);
  final String value;
}

/// Pure contract: can be implemented, not extended or instantiated.
abstract interface class Storage {
  String read(String key);
}

/// Can be used as a class (extended) or as a mixin (applied with 'with').
mixin class Greeter {
  String greet(String name) => 'Hello, $name';
}
// #enddocregion modifiers
