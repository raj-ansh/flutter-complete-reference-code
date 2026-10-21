// #docregion validators
/// A validator returns an error message, or null when the value is acceptable.
typedef Validator = String? Function(String? value);

/// The value must not be empty or only spaces.
Validator notEmpty([String name = 'This field']) {
  return (value) {
    if (value == null || value.trim().isEmpty) return '$name is required';
    return null;
  };
}

/// A deliberately simple e-mail check: something@something.something.
/// (Real validation happens on the server, when you send a message.)
String? email(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null; // leave emptiness to notEmpty()
  final looksRight = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
  return looksRight ? null : 'Enter an address like name@example.com';
}

/// The value must be at least [length] characters long.
Validator minLength(int length) {
  return (value) {
    if (value == null || value.isEmpty) return null;
    return value.length >= length ? null : 'Use at least $length characters';
  };
}

/// Runs validators in order and returns the first error found.
Validator all(List<Validator> validators) {
  return (value) {
    for (final validate in validators) {
      final error = validate(value);
      if (error != null) return error;
    }
    return null;
  };
}
// #enddocregion validators
