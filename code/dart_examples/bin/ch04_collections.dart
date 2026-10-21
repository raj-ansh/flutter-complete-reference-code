void main() {
  // #docregion list
  var numbers = [5, 3, 8, 1];
  numbers.add(9);
  numbers.insert(0, 7);
  print(numbers);
  print(numbers.length);
  print(numbers[2]);
  print(numbers.first);
  print(numbers.last);
  numbers.sort();
  print(numbers);
  print(numbers.contains(8));
  numbers.remove(8);
  print(numbers);
  // #enddocregion list

  // #docregion transform
  var squares = numbers.map((n) => n * n).toList();
  print(squares);
  var big = numbers.where((n) => n > 4).toList();
  print(big);
  var total = numbers.fold<int>(0, (sum, n) => sum + n);
  print(total);
  print(numbers.any((n) => n > 8));
  print(numbers.every((n) => n > 0));
  // #enddocregion transform

  // #docregion set
  var tags = {'dart', 'flutter'};
  tags.add('dart'); // already present: ignored
  print(tags);
  print(tags.length);
  tags.add('widgets');
  print(tags.contains('flutter'));
  print(tags.intersection({'flutter', 'web'}));
  // #enddocregion set

  // #docregion map
  var stock = {'apples': 12, 'pears': 4};
  stock['plums'] = 7;
  print(stock);
  print(stock['apples']);
  print(stock['kiwis']); // null: the key is absent
  print(stock['kiwis'] ?? 0);
  for (var entry in stock.entries) {
    print('${entry.key}: ${entry.value}');
  }
  stock.remove('pears');
  print(stock.keys.toList());
  print(stock.containsKey('plums'));
  // #enddocregion map

  // #docregion typed
  List<String> names = [];
  names.add('Ada');
  // names.add(42); // compile-time error: int is not a String
  Map<String, List<int>> scores = {
    'ada': [90, 95],
    'alan': [88],
  };
  print(names);
  print(scores['ada']);
  // #enddocregion typed

  // #docregion spread
  var base = [1, 2, 3];
  var more = [0, ...base, 4];
  print(more);
  var admin = true;
  var menu = ['Home', 'Profile', if (admin) 'Settings'];
  print(menu);
  var doubled = [for (var n in base) n * 2];
  print(doubled);
  // #enddocregion spread

  // #docregion constlist
  const fixed = [1, 2, 3];
  try {
    fixed.add(4);
  } on UnsupportedError {
    print('cannot modify a const list');
  }
  var frozen = List.unmodifiable(numbers);
  try {
    frozen.add(1);
  } on UnsupportedError {
    print('cannot modify an unmodifiable list');
  }
  // #enddocregion constlist

  // #docregion lazy
  var lazy = numbers.where((n) {
    print('checking $n');
    return n > 4;
  });
  print('nothing printed yet');
  print(lazy.toList());
  // #enddocregion lazy
}
