import 'package:flutter/material.dart';
import 'package:flutter_examples/ch14/navigator_basics.dart';
import 'package:flutter_examples/ch14/other_nav.dart';
import 'package:flutter_examples/ch14/router_demo.dart';
import 'package:flutter_examples/ch14/shell_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

Widget app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
  home: home,
);

String where(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('Navigator', () {
    testWidgets('push waits for a result; back without a result keeps data', (
      tester,
    ) async {
      await tester.pumpWidget(app(const NoteListPage()));
      await tester.tap(find.text('Water tomatoes'));
      await tester.pumpAndSettle();
      expect(find.text('Note 1'), findsOneWidget); // detail screen

      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();
      expect(find.text('Water tomatoes (done)'), findsOneWidget);

      await tester.tap(find.text('Prune roses'));
      await tester.pumpAndSettle();
      await tester.pageBack(); // no result
      await tester.pumpAndSettle();
      expect(find.text('Prune roses'), findsOneWidget);
    });

    testWidgets('push, pushReplacement and popUntil', (tester) async {
      await tester.pumpWidget(app(const StackOps(depth: 1)));
      await tester.tap(find.text('Push deeper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push deeper'));
      await tester.pumpAndSettle();
      expect(find.text('Level 3'), findsOneWidget);

      await tester.tap(find.text('Replace this screen'));
      await tester.pumpAndSettle();
      expect(find.text('Level 4'), findsOneWidget);

      await tester.tap(find.text('Back to start'));
      await tester.pumpAndSettle();
      expect(find.text('Level 1'), findsOneWidget);
    });

    testWidgets('named routes still work', (tester) async {
      await tester.pumpWidget(const NamedRoutesApp());
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.text('Detail for 42'), findsOneWidget);
    });
  });

  group('go_router', () {
    late GoRouter router;

    setUp(() {
      signedIn.value = false;
      router = buildRouter();
    });

    testWidgets('go, push, parameters and the error page', (tester) async {
      final log = StringBuffer();
      await tester.pumpWidget(RouterApp(router: router));
      log.writeln('start:                 ${where(router)}');

      await tester.tap(find.text('Open note 3 (go)'));
      await tester.pumpAndSettle();
      expect(find.text('Note 3'), findsOneWidget);
      log.writeln(
        'after go(/notes/3):    ${where(router)}   canPop=${router.canPop()}',
      );
      expect(router.canPop(), isFalse); // go replaced the stack

      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open note 7 (push)'));
      await tester.pumpAndSettle();
      expect(find.text('Note 7'), findsOneWidget);
      log.writeln(
        'after push(/notes/7):  ${where(router)}   canPop=${router.canPop()}',
      );
      expect(router.canPop(), isTrue); // push stacked a page

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget); // popped back

      await tester.tap(find.text('Search for "tomato"'));
      await tester.pumpAndSettle();
      expect(find.text('Results for "tomato"'), findsOneWidget);
      log.writeln('after go(/search?q=):  ${where(router)}');

      router.go('/nope');
      await tester.pumpAndSettle();
      expect(find.text('No page at /nope'), findsOneWidget);
      log.writeln(
        'after go(/nope):       ${where(router)}  (error page shown)',
      );

      writeCaptured('ch14_locations.txt', log.toString());
    });

    testWidgets('redirect protects /account and returns after sign-in', (
      tester,
    ) async {
      await tester.pumpWidget(RouterApp(router: router));
      final log = StringBuffer();

      router.go('/account'); // not signed in
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Your account'), findsNothing);
      log.writeln('signed out, go(/account) lands on: ${where(router)}');

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Your account'), findsOneWidget);
      log.writeln('after signing in, location is:      ${where(router)}');

      writeCaptured('ch14_redirect.txt', log.toString());
    });
  });

  testWidgets('shell route: each tab keeps its own state', (tester) async {
    final router = buildShellRouter();
    addTearDown(router.dispose);
    await saveScreenshot(
      tester,
      MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
        routerConfig: router,
      ),
      'ch14_shell',
      size: const Size(360, 480),
    );

    final router2 = buildShellRouter();
    addTearDown(router2.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Home count: 2'), findsOneWidget);

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Home details'), findsWidgets);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.text('Search count: 0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    // The Home tab is still on its details page, with its state intact.
    expect(find.text('Home details'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home count: 2'), findsOneWidget);
  });

  testWidgets('tabs, drawer and adaptive navigation', (tester) async {
    await saveScreenshot(
      tester,
      app(const TabsDemo()),
      'ch14_tabs',
      size: const Size(360, 320),
    );
    await tester.pumpWidget(app(const TabsDemo()));
    await tester.tap(find.text('Flowers'));
    await tester.pumpAndSettle();
    expect(find.text('Roses, tulips'), findsOneWidget);

    await saveScreenshot(
      tester,
      app(const DrawerDemo()),
      'ch14_drawer',
      size: const Size(360, 480),
      beforeCapture: (t) async {
        await t.tap(find.byTooltip('Open navigation menu'));
        await t.pumpAndSettle();
      },
    );
    await tester.pumpWidget(app(const DrawerDemo()));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starred'));
    await tester.pumpAndSettle();
    expect(find.text('Showing Starred'), findsOneWidget);

    await saveScreenshot(
      tester,
      app(const AdaptiveNav()),
      'ch14_adaptive_narrow',
      size: const Size(360, 300),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await saveScreenshot(
      tester,
      app(const AdaptiveNav()),
      'ch14_adaptive_wide',
      size: const Size(800, 300),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('PopScope asks before leaving with unsaved changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EditorPage()),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // No changes yet: back works immediately.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch)); // now there are unsaved changes
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsOneWidget); // still here

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget); // left the editor
  });

  testWidgets('stepper moves through its steps', (tester) async {
    await saveScreenshot(
      tester,
      app(const StepperDemo()),
      'ch14_stepper',
      size: const Size(360, 520),
      beforeCapture: (t) async {
        await t.tap(find.text('Continue').hitTestable());
        await t.pumpAndSettle();
      },
    );
    await tester.pumpWidget(app(const StepperDemo()));
    expect(find.text('Choose a name'), findsOneWidget);
    await tester.tap(find.text('Continue').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Pick a plan'), findsOneWidget);
    await tester.tap(find.text('Cancel').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Choose a name'), findsOneWidget);
  });
}
