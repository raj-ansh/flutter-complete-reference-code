// #docregion basics
void main() {
  // A record: a fixed-size, immutable group of values, no class needed.
  var pair = ('Ada', 36);
  print(pair);
  print(pair.$1); // positional fields are $1, $2, ...
  print(pair.$2);

  // Named fields.
  var person = (name: 'Alan', age: 41);
  print(person.name);
  print(person);

  // Mixed positional and named.
  var mixed = (1, 2, label: 'point');
  print(mixed.$1 + mixed.$2);
  print(mixed.label);
  // #enddocregion basics

  // #docregion types
  // Record types are written like the records themselves.
  (String, int) typed = ('Grace', 85);
  ({String name, int age}) typedNamed = (name: 'Grace', age: 85);
  print('$typed $typedNamed');
  // #enddocregion types

  // #docregion equality
  // Records have structural equality: same shape and equal fields.
  print((1, 'a') == (1, 'a'));
  print((1, 'a') == (1, 'b'));
  print((x: 1, y: 2) == (y: 2, x: 1)); // named order does not matter
  // #enddocregion equality

  // #docregion multi
  var (low, high) = minMax([4, 9, 2, 7]);
  print('low=$low high=$high');
  var stats = describe([4, 9, 2, 7]);
  print('${stats.count} items, mean ${stats.mean}');
  var (:count, :mean) = stats; // destructure by name
  print('$count / $mean');
  // #enddocregion multi

  // #docregion swap
  var a = 1, b = 2;
  (a, b) = (b, a); // swap without a temporary variable
  print('a=$a b=$b');
  // #enddocregion swap
}

// #docregion functions
// Return several values without defining a class.
(int, int) minMax(List<int> values) {
  var lo = values.first;
  var hi = values.first;
  for (final v in values) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  return (lo, hi);
}

({int count, double mean}) describe(List<int> values) {
  final total = values.fold<int>(0, (s, v) => s + v);
  return (count: values.length, mean: total / values.length);
}
// #enddocregion functions
