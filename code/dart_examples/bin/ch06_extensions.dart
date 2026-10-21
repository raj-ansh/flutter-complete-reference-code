// #docregion methods
// An extension adds members to an existing type without changing it.
extension StringTools on String {
  /// 'hello world' -> 'Hello World'
  String get titleCase =>
      split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

  bool get isEmail => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(this);
}

extension NumberTools on int {
  Duration get seconds => Duration(seconds: this);
  bool get isPrime {
    if (this < 2) return false;
    for (var i = 2; i * i <= this; i++) {
      if (this % i == 0) return false;
    }
    return true;
  }
}

extension ListTools<T> on List<T> {
  /// Splits a list into chunks of at most [size] items.
  List<List<T>> chunked(int size) => [
    for (var i = 0; i < length; i += size)
      sublist(i, i + size > length ? length : i + size),
  ];
}

// Extensions may also target nullable types.
extension NullableString on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
// #enddocregion methods

// #docregion types
// An extension type wraps a value with zero run-time cost but its own type.
extension type UserId(int value) {
  bool get isValid => value > 0;
}

extension type Meters(double value) {
  Meters operator +(Meters other) => Meters(value + other.value);
  String describe() => '${value.toStringAsFixed(1)} m';
}

void loadUser(UserId id) => print('loading user ${id.value}');
// #enddocregion types

// #docregion run
void main() {
  print('hello dart world'.titleCase);
  print('ada@example.com'.isEmail);
  print('not an email'.isEmail);
  print(5.seconds);
  print([for (var i = 1; i <= 20; i++) i].where((n) => n.isPrime).toList());
  print([1, 2, 3, 4, 5, 6, 7].chunked(3));
  String? nothing;
  print(nothing.isNullOrEmpty);
  print(''.isNullOrEmpty);

  var id = UserId(42);
  loadUser(id);
  print(id.isValid);
  // loadUser(42); // error: an int is not a UserId, even though it wraps one
  print((Meters(1.5) + Meters(2.25)).describe());
}
// #enddocregion run
