// #docregion generic
class Box<T> {
  Box(this.value);
  final T value;

  Box<R> map<R>(R Function(T) transform) => Box(transform(value));

  @override
  String toString() => 'Box($value)';
}

// A function with a bounded type parameter: T must be comparable.
T largest<T extends Comparable<T>>(List<T> items) {
  var best = items.first;
  for (final item in items) {
    if (item.compareTo(best) > 0) best = item;
  }
  return best;
}
// #enddocregion generic

// #docregion enum
enum Priority {
  low(1, 'Low'),
  medium(2, 'Medium'),
  high(3, 'High');

  const Priority(this.weight, this.label);

  final int weight;
  final String label;

  bool get isUrgent => this == high;

  Priority escalate() => switch (this) {
    low => medium,
    medium => high,
    high => high,
  };
}
// #enddocregion enum

// #docregion run
void main() {
  var number = Box(21);
  var text = number.map((n) => 'value is ${n * 2}');
  print(number);
  print(text);
  print(largest([3, 9, 4]));
  print(largest(['pear', 'apple', 'zebra']));

  for (final p in Priority.values) {
    print('${p.name}: ${p.label} weight=${p.weight} urgent=${p.isUrgent}');
  }
  print(Priority.low.escalate());
  print(Priority.high.escalate());
  print(Priority.values.byName('medium').index);
  print(Priority.values.map((p) => p.name).toList());
}
// #enddocregion run
