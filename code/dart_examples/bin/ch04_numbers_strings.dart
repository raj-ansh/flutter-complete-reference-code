// #docregion numbers
void main() {
  int a = 17;
  int b = 5;
  print('a + b = ${a + b}');
  print('a / b = ${a / b}'); // / always gives a double
  print('a ~/ b = ${a ~/ b}'); // integer division
  print('a % b = ${a % b}'); // remainder
  print('2 + 3 * 4 = ${2 + 3 * 4}');

  double price = 19.99;
  print((price * 3).toStringAsFixed(2));
  print(price.round());
  print(price.floor());
  print(10.0 / 4);

  num mixed = 3; // num can hold an int or a double
  mixed = 3.5;
  print(mixed);

  print(int.parse('42') + 1);
  print(double.parse('3.14') * 2);
  print(int.tryParse('forty-two')); // null instead of an exception
  // #enddocregion numbers

  // #docregion strings
  var first = 'Grace';
  var last = "Hopper";
  print('$first $last');
  print('Name length: ${(first + last).length}');
  print('${first.toUpperCase()} / ${last.toLowerCase()}');

  var multi = '''
Line one
Line two''';
  print(multi);

  var path = r'C:\temp\new'; // raw string: backslashes are literal
  print(path);

  var words = 'to be or not to be';
  print(words.split(' ').length);
  print(words.contains('not'));
  print(words.replaceAll('be', 'BE'));
  print(words.substring(3, 5));
  print('  padded  '.trim());
  print('7'.padLeft(3, '0'));

  var buffer = StringBuffer();
  for (var i = 1; i <= 3; i++) {
    buffer.write('item$i ');
  }
  print(buffer.toString().trim());
  // #enddocregion strings
}
