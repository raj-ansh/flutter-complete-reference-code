// #docregion reminder
/// An immutable value with an optional field, to show the copyWith problem.
class Reminder {
  const Reminder({required this.title, this.due});

  final String title;
  final DateTime? due;

  /// The simple version from Chapter 5. Passing null means "keep the old
  /// value", so it can never clear [due].
  Reminder copyWithSimple({String? title, DateTime? due}) =>
      Reminder(title: title ?? this.title, due: due ?? this.due);

  /// Workaround 1: wrap the nullable parameter in a function. Omitting it
  /// keeps the value; passing `() => null` clears it.
  Reminder copyWith({String? title, DateTime? Function()? due}) => Reminder(
    title: title ?? this.title,
    due: due != null ? due() : this.due,
  );

  /// Workaround 2: a separate, clearly named method for the special case.
  Reminder withoutDue() => Reminder(title: title);
}
// #enddocregion reminder
