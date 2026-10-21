void main() {
  // #docregion ifelse
  var temperature = 24;
  if (temperature > 30) {
    print('hot');
  } else if (temperature > 20) {
    print('warm');
  } else {
    print('cool');
  }
  // #enddocregion ifelse

  // #docregion loops
  for (var i = 0; i < 3; i++) {
    print('for: $i');
  }

  var fruits = ['apple', 'banana', 'cherry'];
  for (var fruit in fruits) {
    print('for-in: $fruit');
  }

  var n = 3;
  while (n > 0) {
    print('while: $n');
    n--;
  }

  var tries = 0;
  do {
    tries++;
  } while (tries < 3);
  print('do-while ran $tries times');
  // #enddocregion loops

  // #docregion breakcontinue
  for (var i = 1; i <= 10; i++) {
    if (i.isOdd) continue; // skip odd numbers
    if (i > 6) break; // stop after 6
    print('even: $i');
  }
  // #enddocregion breakcontinue

  // #docregion switch
  var command = 'stop';
  switch (command) {
    case 'start':
      print('starting');
    case 'stop':
    case 'halt':
      print('stopping');
    default:
      print('unknown command');
  }
  // #enddocregion switch

  // #docregion ternary
  var age = 17;
  var label = age >= 18 ? 'adult' : 'minor';
  print(label);
  // #enddocregion ternary
}
