// #docregion pitfalls
void main() {
  // 1. Index out of range.
  var items = ['a', 'b', 'c'];
  try {
    print(items[3]);
  } on RangeError catch (e) {
    print('RangeError: $e');
  }

  // 2. Parsing text that is not a number.
  try {
    print(int.parse('12x'));
  } on FormatException catch (e) {
    print('FormatException: ${e.message}');
  }
  print(int.tryParse('12x') ?? 'not a number');

  // 3. "var" without a value is dynamic, so the compiler cannot help you.
  var loose;
  loose = 1;
  loose = 'now text';
  print(loose.runtimeType);

  // 4. Floating-point arithmetic is not exact.
  print(0.1 + 0.2);
  print((0.1 + 0.2) == 0.3);
  print(((0.1 + 0.2) - 0.3).abs() < 1e-9);

  // 5. Dividing by zero.
  print(1 / 0);
  try {
    print(1 ~/ 0);
  } on UnsupportedError catch (e) {
    print('UnsupportedError: $e');
  }

  // 6. String length counts UTF-16 code units, not what a person sees.
  var smile = '\u{1F600}';
  print(smile.length);
}
// #enddocregion pitfalls
