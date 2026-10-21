import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_examples/ch31/keyboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // #docregion keyboardtest
  testWidgets('Ctrl+N adds an item and Delete removes the last one', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: KeyboardList())),
    );
    expect(find.text('1 items'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(find.text('1 items'), findsOneWidget);
    expect(find.text('Item 2'), findsNothing);
  });
  // #enddocregion keyboardtest
}
