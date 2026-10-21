// #docregion basic
int square(int n) {
  return n * n;
}

// Arrow syntax: a function whose body is a single expression.
int cube(int n) => n * n * n;

void greet(String name) {
  print('Hello, $name!');
}
// #enddocregion basic

// #docregion params
// Optional positional parameters go in square brackets.
String describe(String name, [int? age, String country = 'unknown']) {
  var result = name;
  if (age != null) result += ' ($age)';
  return '$result from $country';
}

// Named parameters go in braces. 'required' makes one mandatory.
String formatPrice({
  required double amount,
  String currency = 'EUR',
  int decimals = 2,
}) {
  return '${amount.toStringAsFixed(decimals)} $currency';
}
// #enddocregion params

// #docregion firstclass
// Functions are values: they can be passed in and returned.
int applyTwice(int Function(int) f, int value) => f(f(value));

typedef Predicate<T> = bool Function(T value);

List<T> keepIf<T>(List<T> items, Predicate<T> test) {
  return [
    for (final item in items)
      if (test(item)) item,
  ];
}

// A function that returns a function.
int Function(int) makeAdder(int amount) {
  return (int n) => n + amount; // captures 'amount'
}
// #enddocregion firstclass

// #docregion closure
Function() makeCounter() {
  var count = 0; // lives on because the returned function uses it
  return () {
    count++;
    return count;
  };
}
// #enddocregion closure

// #docregion run
void main() {
  print(square(4));
  print(cube(3));
  greet('Dart');

  print(describe('Ada'));
  print(describe('Alan', 41));
  print(describe('Grace', 85, 'USA'));
  print(formatPrice(amount: 12.5));
  print(formatPrice(currency: 'USD', amount: 3, decimals: 0));

  print(applyTwice(square, 3));
  print(applyTwice((n) => n + 10, 1));
  print(keepIf<int>([1, 2, 3, 4, 5, 6], (n) => n.isEven));
  print(keepIf(['apple', 'fig', 'banana'], (s) => s.length > 3));

  var addFive = makeAdder(5);
  print(addFive(10));

  var counterA = makeCounter();
  var counterB = makeCounter();
  print(counterA());
  print(counterA());
  print(counterB());
  print(counterA());

  // An anonymous function passed directly.
  var nums = [3, 1, 2];
  nums.sort((a, b) => b.compareTo(a)); // largest first
  print(nums);
  var words = ['pear', 'fig', 'apple'];
  words.sort((a, b) => a.length.compareTo(b.length));
  print(words);
}
// #enddocregion run
