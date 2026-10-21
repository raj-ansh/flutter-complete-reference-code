// #docregion nullable
void main() {
  String name = 'Ada'; // can never be null
  String? nickname = findNickname(); // may be null

  print(name.length);
  print(nickname); // null
  // print(nickname.length); // compile-time error: nickname might be null
  // #enddocregion nullable

  // #docregion operators
  print(nickname?.length); // null-aware access: null when nickname is null
  print(nickname ?? 'no nickname'); // default value when null
  nickname ??= 'Countess'; // assign only if currently null
  print(nickname);
  print(nickname.length); // OK: Dart knows it is not null here
  // #enddocregion operators

  // #docregion promotion
  String? input = readInput();
  if (input != null) {
    // Inside this block, 'input' is promoted to String.
    print('Length: ${input.length}');
  } else {
    print('No input');
  }
  // #enddocregion promotion

  // #docregion bang
  String? maybe = readInput();
  // The ! operator tells Dart "I know this is not null".
  // If you are wrong, the program throws at run time.
  try {
    print(maybe!.length);
  } catch (e) {
    print('Caught: $e');
  }
  // #enddocregion bang

  // #docregion late
  late final String config = loadConfig(); // runs on first use
  print('before use');
  print(config);
  // #enddocregion late
}

String? readInput() => null;

String? findNickname() => null; // pretend a lookup found nothing

String loadConfig() {
  print('loading config...');
  return 'config-v1';
}
