import 'dart:async';

// #docregion generator
// An async* function is a generator: it yields values over time.
Stream<int> countTo(int max) async* {
  for (var i = 1; i <= max; i++) {
    await Future.delayed(const Duration(milliseconds: 10));
    yield i;
  }
}
// #enddocregion generator

// #docregion run
Future<void> main() async {
  // await for consumes a stream one value at a time.
  await for (final n in countTo(3)) {
    print('received $n');
  }

  // Streams can be transformed like lists.
  var evens = countTo(8).where((n) => n.isEven).map((n) => n * 10);
  print(await evens.toList());

  // listen() is the callback style.
  var done = Completer<void>();
  countTo(2).listen(
    (n) => print('listen got $n'),
    onError: (Object e) => print('error $e'),
    onDone: () {
      print('stream done');
      done.complete();
    },
  );
  await done.future;

  // A StreamController lets your code push values into a stream.
  var controller = StreamController<String>();
  var sub = controller.stream.listen((msg) => print('message: $msg'));
  controller.add('hello');
  controller.add('world');
  await Future<void>.delayed(Duration.zero);
  await sub.cancel(); // stop listening
  await controller.close();

  // A controller's stream is single-subscription: one listener only.
  var single = StreamController<int>();
  single.stream.listen((n) => print('first listener got $n'));
  try {
    single.stream.listen((n) => print('never used'));
  } on StateError catch (e) {
    print('second listen: ${e.message}');
  }
  single.add(1);
  await Future<void>.delayed(Duration.zero);
  await single.close();

  // A broadcast stream allows many listeners.
  var chat = StreamController<String>.broadcast();
  chat.stream.listen((m) => print('A saw $m'));
  chat.stream.listen((m) => print('B saw $m'));
  chat.add('hi');
  await Future<void>.delayed(Duration.zero);
  await chat.close();

  // Streams carry errors too.
  Stream<int> failing() async* {
    yield 1;
    throw StateError('boom');
  }

  try {
    await for (final v in failing()) {
      print('value $v');
    }
  } on StateError catch (e) {
    print('stream failed: ${e.message}');
  }
}
// #enddocregion run
