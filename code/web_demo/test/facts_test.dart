import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_demo/main.dart';

void main() {
  test('the facts describe the test environment', () {
    final facts = platformFacts();
    expect(facts['Running in a browser (kIsWeb)'], 'false');
    expect(facts['Compiled to WebAssembly'], 'false');
    expect(facts.length, 5);
  });

  testWidgets('every fact is shown as a list tile', (tester) async {
    await tester.pumpWidget(const PlatformFactsApp());
    expect(find.byType(ListTile), findsNWidgets(5));
    expect(find.text('Target platform'), findsOneWidget);
  });
}
