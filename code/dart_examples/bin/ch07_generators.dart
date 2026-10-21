// #docregion sync
// A sync* function is a generator that produces an Iterable lazily:
// code runs only as far as the consumer asks.
Iterable<int> naturals(int max) sync* {
  for (var i = 1; i <= max; i++) {
    print('  producing $i');
    yield i;
  }
}

// yield* hands over to another iterable.
Iterable<int> countdown(int n) sync* {
  if (n > 0) {
    yield n;
    yield* countdown(n - 1);
  }
}
// #enddocregion sync

// #docregion run
void main() {
  var numbers = naturals(4);
  print('created, nothing produced yet');

  var iterator = numbers.iterator;
  iterator.moveNext();
  print('got ${iterator.current}');
  iterator.moveNext();
  print('got ${iterator.current}');

  print('take(2) of a fresh run:');
  print(naturals(10).take(2).toList());

  print(countdown(4).toList());
}
// #enddocregion run
