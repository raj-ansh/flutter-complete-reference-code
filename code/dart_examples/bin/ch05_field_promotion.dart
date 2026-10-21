// #docregion session
class Session {
  String? token;

  // Copy the field into a local variable. Dart can prove a local
  // variable does not change between the check and the use.
  int tokenLength() {
    final t = token;
    if (t != null) {
      return t.length; // promoted to String
    }
    return 0;
  }

  // Another common form: use a null-aware operator.
  int tokenLengthShort() => token?.length ?? 0;
}
// #enddocregion session

void main() {
  final s = Session();
  print(s.tokenLength());
  s.token = 'abc123';
  print(s.tokenLength());
  print(s.tokenLengthShort());
}
