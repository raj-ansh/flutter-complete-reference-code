// #docregion custom
// An Exception describes a problem the caller may reasonably handle.
class InsufficientFunds implements Exception {
  InsufficientFunds(this.needed, this.available);
  final double needed;
  final double available;

  @override
  String toString() =>
      'InsufficientFunds: needed $needed but only $available available';
}

void withdraw(double balance, double amount) {
  if (amount <= 0) {
    // An Error signals a programmer mistake: the caller broke a rule.
    throw ArgumentError.value(amount, 'amount', 'must be positive');
  }
  if (amount > balance) throw InsufficientFunds(amount, balance);
  print('withdrew $amount');
}
// #enddocregion custom

// #docregion run
void main() {
  // Catch by type, most specific first.
  for (final amount in [20.0, 500.0, -1.0]) {
    try {
      withdraw(100, amount);
    } on InsufficientFunds catch (e) {
      print('cannot withdraw: ${e.needed - e.available} short');
    } on ArgumentError catch (e) {
      print('bad call: ${e.message}');
    } finally {
      print('checked $amount');
    }
  }

  // Catch anything, keep the stack trace, and rethrow.
  try {
    try {
      int.parse('oops');
    } catch (e, stack) {
      print('logging a ${e.runtimeType}');
      print('has a stack trace: ${stack.toString().isNotEmpty}');
      rethrow; // let the caller see it too
    }
  } on FormatException {
    print('outer handler got the same exception');
  }

  // Throwing anything is legal, but throw Exceptions or Errors.
  try {
    throw 'a plain string';
  } catch (e) {
    print('caught a ${e.runtimeType}');
  }

  // StateError, UnsupportedError, RangeError are Errors built into Dart.
  try {
    <int>[].first;
  } on StateError catch (e) {
    print('empty list: ${e.message}');
  }

  // Exception vs Error, as types.
  Object e1 = InsufficientFunds(1, 0);
  Object e2 = ArgumentError('x');
  print('${e1 is Exception} ${e1 is Error}');
  print('${e2 is Exception} ${e2 is Error}');
}
// #enddocregion run
