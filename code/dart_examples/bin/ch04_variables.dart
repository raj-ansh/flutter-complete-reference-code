// #docregion declare
void main() {
  // Type inferred from the value.
  var city = 'Lisbon';
  var year = 2026;
  var ratio = 0.75;
  var ready = true;

  // Explicit types.
  String country = 'Portugal';
  int population = 545_796; // digit separators are allowed
  double areaKm2 = 100.05;
  bool isCapital = true;

  print('$city, $country ($year): $population people, $areaKm2 km2');
  print('ratio=$ratio ready=$ready capital=$isCapital');
  // #enddocregion declare

  // #docregion types
  print(city.runtimeType);
  print(year.runtimeType);
  print(ratio.runtimeType);
  print(ready.runtimeType);
  // #enddocregion types

  // #docregion final_const
  final startedAt = DateTime.now(); // known only at run time
  const maxRetries = 3; // known at compile time
  const greeting = 'Hello';
  const doubled = maxRetries * 2; // constant expressions are allowed
  print('startedAt is a ${startedAt.runtimeType}');
  print('$greeting, retries=$maxRetries, doubled=$doubled');
  // #enddocregion final_const

  // #docregion reassign
  var counter = 1;
  counter = counter + 1; // fine: a var can be reassigned
  final label = 'fixed';
  // label = 'changed'; // error: a final variable can only be set once
  print('counter=$counter label=$label');
  // #enddocregion reassign

  // #docregion dynamic
  dynamic anything = 42;
  print(anything.runtimeType);
  anything = 'now a string';
  print(anything.runtimeType);
  // #enddocregion dynamic
}
