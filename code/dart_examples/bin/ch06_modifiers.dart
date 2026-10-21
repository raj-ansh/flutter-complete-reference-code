import 'package:dart_examples/modifiers.dart';

// #docregion allowed
// The allowed uses, from another library:
class FancyPrinter implements Printer {
  @override
  void printLine(String text) => print('** $text **');
}

base class User extends Entity {
  User(super.id, this.name);
  final String name;
}

class MemoryStorage implements Storage {
  final Map<String, String> _data = {'color': 'blue'};

  @override
  String read(String key) => _data[key] ?? '';
}

class Welcome with Greeter {}
// #enddocregion allowed

void main() {
  FancyPrinter().printLine('hello');
  final user = User(7, 'Ada');
  print('${user.id} ${user.name}');
  print(MemoryStorage().read('color'));
  print(Welcome().greet('Grace'));
  print(const Token('abc').value);
  // 'new Storage()' is not allowed: it is abstract.
}
