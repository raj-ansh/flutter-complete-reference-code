void main() {
  // #docregion ops
  print(7 + 2);
  print(7 - 2);
  print(7 * 2);
  print(7 / 2);
  print(7 ~/ 2);
  print(7 % 2);
  print(-7 % 3); // the remainder is never negative in Dart
  print(7 == 7.0);
  print(7 != 8);
  print(identical('a', 'a'));
  print(5 > 3 && 2 > 1);
  print(5 > 3 || 1 > 2);
  print(!true);
  // #enddocregion ops

  // #docregion incr
  var x = 5;
  print(x++); // use, then increment
  print(x);
  print(++x); // increment, then use
  x += 10;
  print(x);
  x *= 2;
  print(x);
  // #enddocregion incr

  // #docregion bits
  print(5 & 3); // and
  print(5 | 3); // or
  print(5 ^ 3); // xor
  print(1 << 4); // shift left
  print(256 >> 2); // shift right
  // #enddocregion bits

  // #docregion typetest
  Object value = 'text';
  print(value is String);
  print(value is int);
  if (value is String) {
    print(value.toUpperCase()); // promoted to String
  }
  var asNum = 3 as num;
  print(asNum);
  // #enddocregion typetest

  // #docregion cascade
  var buffer = StringBuffer()
    ..write('a')
    ..write('b')
    ..write('c');
  print(buffer);
  // #enddocregion cascade
}
