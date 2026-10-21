import 'dart:io';

/// Removes machine-specific paths from captured text.
String sanitize(String text) {
  return text
      .replaceAll(RegExp(r'file:///[^\s:]*?/flutter_examples/'), '')
      .replaceAll(RegExp(r'[A-Za-z]:[\\/][^\s:]*?flutter_examples[\\/]'), '');
}

/// Writes text captured while a test runs into `book/code/captured/`,
/// so the book can quote real output instead of retyped output.
void writeCaptured(String fileName, String content) {
  final dir = Directory('${Directory.current.path}/../captured');
  dir.createSync(recursive: true);
  final text = sanitize(content);
  final withNewline = text.endsWith('\n') ? text : '$text\n';
  File('${dir.path}/$fileName').writeAsStringSync(withNewline);
}
