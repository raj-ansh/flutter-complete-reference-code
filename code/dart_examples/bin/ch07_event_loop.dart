import 'dart:async';

// #docregion order
void main() {
  print('1: main starts');

  Future(() => print('5: event-queue task'));

  scheduleMicrotask(() => print('3: microtask'));

  Future.microtask(() => print('4: microtask created by Future'));

  print('2: main ends');
}
// #enddocregion order
