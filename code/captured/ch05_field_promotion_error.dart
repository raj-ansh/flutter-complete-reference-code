class Session {
  String? token;

  int tokenLength() {
    if (token != null) {
      return token.length;
    }
    return 0;
  }
}

void main() {}
