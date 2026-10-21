import 'dart:math' as math;

// #docregion point
class Point {
  // Fields. 'final' means they are set once, in the constructor.
  final double x;
  final double y;

  // A constructor using "initializing formals": this.x and this.y
  // assign the arguments straight to the fields.
  const Point(this.x, this.y);

  // A named constructor.
  const Point.origin() : x = 0, y = 0;

  // A method.
  double distanceTo(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  // A getter: looks like a field, computed on demand.
  bool get isOrigin => x == 0 && y == 0;

  // Operator overloading.
  Point operator +(Point other) => Point(x + other.x, y + other.y);

  // Value equality: two points with equal coordinates are equal.
  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}

// #enddocregion point

// #docregion account
class Account {
  Account(this.owner, double openingBalance) : _balance = openingBalance;

  final String owner;
  double _balance; // private: the underscore hides it from other files

  double get balance => _balance;

  // A setter with validation.
  set nickname(String value) {
    if (value.isEmpty) throw ArgumentError('Nickname must not be empty');
    _nickname = value;
  }

  String _nickname = '';
  String get nickname => _nickname;

  void deposit(double amount) {
    if (amount <= 0)
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    _balance += amount;
  }

  static int created = 0; // belongs to the class, not to an instance
  static Account open(String owner) {
    created++;
    return Account(owner, 0);
  }
}
// #enddocregion account

// #docregion immutable
class Profile {
  const Profile({required this.name, required this.email, this.age});

  final String name;
  final String email;
  final int? age;

  // "Change" an immutable object by making a modified copy.
  Profile copyWith({String? name, String? email, int? age}) {
    return Profile(
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
    );
  }

  @override
  String toString() => 'Profile($name, $email, $age)';
}
// #enddocregion immutable

// #docregion factory
class Logger {
  Logger._(this.name);

  final String name;
  static final Map<String, Logger> _cache = {};

  // A factory constructor may return an existing instance.
  factory Logger(String name) {
    return _cache.putIfAbsent(name, () => Logger._(name));
  }
}
// #enddocregion factory

// #docregion run
void main() {
  const a = Point(3, 4);
  const b = Point.origin();
  print(a);
  print(b.isOrigin);
  print(a.distanceTo(b));
  print(a + const Point(1, 1));
  print(a == const Point(3, 4));
  print(identical(a, const Point(3, 4)));
  print([a, const Point(3, 4)].toSet().length);

  var account = Account.open('Ada');
  account.deposit(100);
  account.nickname = 'Countess';
  print('${account.owner}: ${account.balance} (${account.nickname})');
  try {
    account.deposit(-5);
  } on ArgumentError catch (e) {
    print('Rejected: $e');
  }
  print(Account.created);

  var p = const Profile(name: 'Ada', email: 'ada@example.com');
  var older = p.copyWith(age: 36);
  print(p);
  print(older);

  print(identical(Logger('app'), Logger('app')));
  print(identical(Logger('app'), Logger('db')));
}
// #enddocregion run
