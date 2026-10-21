// #docregion validation
/// Each validator returns an error message for the user, or null when the
/// value is acceptable. They are plain functions, so they work with form
/// fields and in the view model alike, and are tested without widgets.
String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter a name';
  if (value.trim().length > 80) return 'Keep the name under 80 characters';
  return null;
}

/// Empty is allowed. Otherwise: digits with optional spaces, dashes,
/// brackets and one leading plus, and at least 3 digits.
String? validatePhone(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\+?[0-9 ()\-]+$').hasMatch(text)) {
    return 'Use digits, spaces, dashes and brackets only';
  }
  if (RegExp(r'[0-9]').allMatches(text).length < 3) {
    return 'A phone number needs at least 3 digits';
  }
  return null;
}

/// Empty is allowed. This deliberately checks only the basic shape (something,
/// an @, something with a dot): the only real test of an address is sending
/// mail to it.
String? validateEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
    return 'Enter an address like name@example.com';
  }
  return null;
}
// #enddocregion validation
