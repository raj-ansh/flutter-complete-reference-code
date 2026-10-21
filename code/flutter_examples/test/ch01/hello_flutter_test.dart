import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_examples/ch01/hello_flutter.dart';

void main() {
  testWidgets('HelloApp shows its greeting', (tester) async {
    await tester.pumpWidget(const HelloApp());
    expect(find.text('Hello, Flutter!'), findsOneWidget);
  });
}
