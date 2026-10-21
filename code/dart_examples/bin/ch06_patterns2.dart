// #docregion more
String describe(Object? value) => switch (value) {
  // Logical-or: several patterns, one result.
  'yes' || 'y' || 'true' => 'affirmative',
  // Logical-and with a relational pattern: a range test.
  int _ && > 0 && < 10 => 'small positive int',
  // Null-check pattern (a trailing ?): matches only non-null values.
  var other? => 'non-null: $other',
  _ => 'it was null',
};

// Cast pattern: assert a type while destructuring.
int firstAsInt(List<Object> items) {
  var [first as int, ...] = items;
  return first;
}

// Null-assert pattern: destructure and throw if null.
String requireName(Map<String, String?> data) {
  var {'name': name!} = data;
  return name;
}

void main() {
  print(describe('y'));
  print(describe(5));
  print(describe(50));
  print(describe('hi'));
  print(describe(null));
  print(firstAsInt([7, 'x']));
  try {
    firstAsInt(['not an int']);
  } on TypeError catch (e) {
    print('TypeError: ${e.runtimeType}');
  }
  print(requireName({'name': 'Ada'}));
  try {
    requireName({'name': null});
  } catch (e) {
    print('Caught: $e');
  }
  // #enddocregion more

  // #docregion nullaware
  // Null-aware elements (?x) include a value only when it is not null.
  String? maybeTitle;
  String? maybeSubtitle = subtitleFromServer();
  var lines = ['Header', ?maybeTitle, ?maybeSubtitle, 'Footer'];
  print(lines);
  var map = {'a': 1, 'b': ?lookup('b'), 'c': ?lookup('missing')};
  print(map);
}

String? subtitleFromServer() => 'Intro';

int? lookup(String key) => key == 'b' ? 2 : null;
// #enddocregion nullaware
