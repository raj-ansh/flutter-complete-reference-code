import 'package:flutter/material.dart';
import 'package:flutter_examples/ch11/controls_demo.dart';
import 'package:flutter_examples/ch11/dismissible_demo.dart';
import 'package:flutter_examples/ch11/field_gallery.dart';
import 'package:flutter_examples/ch11/login_form.dart';
import 'package:flutter_examples/ch11/pickers_demo.dart';
import 'package:flutter_examples/ch11/validators.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

Widget app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
  home: home,
);

void main() {
  group('validators', () {
    test('notEmpty', () {
      expect(notEmpty('Email')(''), 'Email is required');
      expect(notEmpty('Email')('   '), 'Email is required');
      expect(notEmpty('Email')('a'), isNull);
    });

    test('email', () {
      expect(email('ada@example.com'), isNull);
      expect(email('ada@'), isNotNull);
      expect(email('no at sign'), isNotNull);
      expect(email(''), isNull); // emptiness is notEmpty's job
    });

    test('all returns the first error', () {
      final v = all([notEmpty('Email'), email]);
      expect(v(''), 'Email is required');
      expect(v('oops'), 'Enter an address like name@example.com');
      expect(v('a@b.co'), isNull);
    });
  });

  testWidgets('login form: errors appear, then a valid submit works', (
    tester,
  ) async {
    await saveScreenshot(
      tester,
      app(const LoginPage()),
      'ch11_login_empty',
      size: const Size(360, 420),
    );

    // Submit with nothing filled in: both errors appear.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    await saveScreenshot(
      tester,
      app(const LoginPage()),
      'ch11_login_errors',
      size: const Size(360, 420),
      beforeCapture: (t) async {
        await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await t.pump();
      },
    );

    // Short password and bad email give specific messages.
    await tester.pumpWidget(app(const LoginPage()));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ada@');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'short',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter an address like name@example.com'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    // Valid values are submitted.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ada@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'correct horse',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Signed in as ada@example.com'), findsOneWidget);
  });

  testWidgets('login form: password visibility toggle', (tester) async {
    await tester.pumpWidget(app(const LoginPage()));
    EditableText passwordField() => tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Password'),
        matching: find.byType(EditableText),
      ),
    );
    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('field gallery and live counter', (tester) async {
    await saveScreenshot(
      tester,
      app(const Scaffold(body: FieldGallery())),
      'ch11_fields',
      size: const Size(360, 640),
    );

    await tester.pumpWidget(
      app(
        const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: LiveCounter()),
        ),
      ),
    );
    expect(find.text('40 characters left'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(find.text('35 characters left'), findsOneWidget);
  });

  testWidgets('digits-only formatter rejects letters', (tester) async {
    await tester.pumpWidget(app(const Scaffold(body: FieldGallery())));
    final pin = find.widgetWithText(TextField, 'PIN');
    await tester.enterText(pin, '12ab34567');
    await tester.pump();
    final controller = tester.widget<TextField>(pin).controller;
    // The decoration-only TextField has no controller, so read the editable text.
    final text = tester
        .widget<EditableText>(
          find.descendant(of: pin, matching: find.byType(EditableText)),
        )
        .controller
        .text;
    expect(controller, isNull);
    expect(text, '1234');
  });

  testWidgets('selection controls respond to taps', (tester) async {
    await saveScreenshot(
      tester,
      app(const Scaffold(body: ControlsDemo())),
      'ch11_controls',
      size: const Size(360, 780),
    );

    await tester.pumpWidget(app(const Scaffold(body: ControlsDemo())));
    await tester.tap(find.text('Reminders'));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await tester.tap(find.text('daily'));
    await tester.pump();
    final group = tester.widget<RadioGroup<Watering>>(
      find.byType(RadioGroup<Watering>),
    );
    expect(group.groupValue, Watering.daily);
  });

  testWidgets('date and time pickers', (tester) async {
    final today = DateTime(2026, 10, 14);
    await tester.pumpWidget(app(PickersDemo(today: today)));
    expect(find.text('No date'), findsOneWidget);

    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    await saveScreenshot(
      tester,
      app(PickersDemo(today: today)),
      'ch11_date_picker',
      size: const Size(360, 700),
      beforeCapture: (t) async {
        await t.tap(find.text('Pick a date'));
        await t.pumpAndSettle();
      },
    );

    await tester.pumpWidget(app(PickersDemo(today: today)));
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    writeCaptured(
      'ch11_picked_date.txt',
      'After choosing day 20 and pressing OK the screen shows:\n'
          '${(tester.widget<Text>(find.textContaining('2026').last)).data}',
    );
    expect(find.textContaining('October 20, 2026'), findsOneWidget);

    await tester.tap(find.text('Pick a time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('9:30 AM'), findsOneWidget);
  });

  testWidgets('swipe to dismiss removes an item', (tester) async {
    await tester.pumpWidget(app(const Scaffold(body: SwipeList())));
    expect(find.text('Prune roses'), findsOneWidget);

    await tester.drag(find.text('Prune roses'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Prune roses'), findsNothing);
    expect(find.text('Water tomatoes'), findsOneWidget);
    expect(find.text('Buy compost'), findsOneWidget);
  });
}
