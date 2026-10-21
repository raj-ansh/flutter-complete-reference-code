import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_app/app.dart';
import 'package:relay_app/data/models.dart';
import 'package:relay_app/data/transport.dart';

import 'support/fakes.dart';
import 'support/screenshot.dart';

/// A stream delivers events in a later microtask: pump twice (Chapter 21).
Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

/// While the connection banner shows, its spinner never stops animating, so
/// pumpAndSettle would wait forever (and time out). Pump a fixed amount of
/// time instead, long enough for dialogs and sheets to finish opening.
Future<void> later(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

class Harness {
  Harness({Map<String, String> saved = const {}}) : transport = FakeTransport() {
    backend = FakeBackend(transport);
    deps = depsWith(transport: transport, store: memoryStore(saved));
  }
  final FakeTransport transport;
  late final FakeBackend backend;
  late final RelayDependencies deps;

  Widget get app => RelayApp(key: UniqueKey(), dependencies: deps);
}

void main() {
  testWidgets('signed out: the sign-in screen, with a clear error for a wrong password', (tester) async {
    final h = Harness();
    await tester.pumpWidget(h.app);
    await settle(tester);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);
    expect(find.text('Wrong username or password.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget, reason: 'still on the sign-in screen');
    expect(h.transport.connectCalls, 0);
  });

  testWidgets('the password can be shown and the form switches to "create account"', (tester) async {
    await tester.pumpWidget(Harness().app);
    await settle(tester);
    TextField password() => tester.widget<TextField>(find.widgetWithText(TextField, 'Password'));
    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(password().obscureText, isFalse);

    await tester.tap(find.text('Create a new account'));
    await tester.pump();
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('At least 10 characters'), findsOneWidget);
  });

  testWidgets('a bad server address is explained before any request is made', (tester) async {
    final h = Harness();
    await tester.pumpWidget(h.app);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Server'), 'ftp://nope');
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'a long enough password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);
    expect(find.text('The address must start with http:// or https://.'), findsOneWidget);
  });

  testWidgets('signing in reaches the lobby and opens the connection', (tester) async {
    final h = Harness();
    h.backend.addRoom(roomJson('r1', 'Garden club'));
    await tester.pumpWidget(h.app);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'a long enough password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Rooms'), findsOneWidget);
    expect(find.text('Garden club'), findsOneWidget);
    expect(h.transport.lastToken, 'token-alice');
  });

  testWidgets('a saved session skips sign-in; the banner shows until connected', (tester) async {
    final h = Harness(saved: savedSession());
    h.backend.addRoom(roomJson('r1', 'Garden club'));
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    expect(find.text('Rooms'), findsOneWidget);
    expect(find.textContaining('Not connected'), findsOneWidget);

    h.transport.emit(const Connected());
    await settle(tester);
    expect(find.textContaining('Not connected'), findsNothing);
    h.transport.emit(const Disconnected('transport close'));
    await settle(tester);
    expect(find.textContaining('Not connected'), findsOneWidget);
  });

  testWidgets('the lobby groups rooms and joining an invitation opens the room', (tester) async {
    final h = Harness(saved: savedSession());
    h.backend
      ..addRoom(roomJson('r1', 'Garden club'))
      ..addRoom(roomJson('r2', 'Secret plans', isPublic: false, ownerId: 'u-bob', joined: false, invited: true), history: [messageJson('r2', 1, 'welcome', userId: 'u-bob', username: 'bob')])
      ..addRoom(roomJson('r3', 'Lounge', ownerId: 'u-bob', joined: false));
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    for (final header in ['Invitations', 'Your rooms', 'Public rooms']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    await tester.tap(find.text('Accept'));
    await settle(tester);
    await settle(tester);
    expect(find.text('welcome'), findsOneWidget); // inside the room now
    expect(find.widgetWithText(AppBar, 'Secret plans'), findsOneWidget);
  });

  testWidgets('a new invitation is announced once', (tester) async {
    final h = Harness(saved: savedSession());
    h.backend.addRoom(roomJson('r1', 'Garden club'));
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    h.backend.addRoom(roomJson('r9', 'Plans', isPublic: false, ownerId: 'u-carol', joined: false, invited: true));
    h.transport.emit(InviteArrived(Invite.fromJson({'room': h.backend.rooms.last, 'from': 'carol'})));
    await settle(tester);
    await settle(tester);
    expect(find.text('carol invited you to "Plans"'), findsOneWidget);
    expect(find.text('Invitations'), findsOneWidget);
  });

  testWidgets('creating a room opens it', (tester) async {
    final h = Harness(saved: savedSession());
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    expect(find.textContaining('No rooms yet'), findsOneWidget);
    await tester.tap(find.byTooltip('New room'));
    await later(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Book club');
    await tester.tap(find.text('Anyone can join')); // switch it off: private
    await tester.pump();
    await tester.tap(find.text('Create'));
    await settle(tester);
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Book club'), findsOneWidget);
    expect(h.backend.rooms.single['isPublic'], false);
  });

  testWidgets('chatting: my message on the right, theirs on the left, the box clears', (tester) async {
    final h = Harness(saved: savedSession());
    h.backend.addRoom(roomJson('r1', 'Garden club'), history: [messageJson('r1', 1, 'Hi from Bob', userId: 'u-bob', username: 'bob')]);
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    await tester.tap(find.text('Garden club'));
    await settle(tester);
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Message'), 'Hello everyone');
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Hello everyone'), findsOneWidget, reason: 'shown once, not twice');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Message')).controller!.text, '');

    h.backend.incoming('r1', 'Welcome!');
    await settle(tester);
    expect(find.text('Welcome!'), findsOneWidget);

    final mine = tester.getTopRight(find.text('Hello everyone')).dx;
    final theirs = tester.getTopLeft(find.text('Hi from Bob')).dx;
    expect(mine, greaterThan(theirs + 100), reason: 'my bubble is on the right');
  });

  testWidgets('a rejected message stays in the box with the reason', (tester) async {
    final h = Harness(saved: savedSession());
    h.backend.addRoom(roomJson('r1', 'Garden club'));
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    await tester.tap(find.text('Garden club'));
    await settle(tester);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Message'), 'too fast');
    h.backend.failNext = 'rate_limited';
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
    expect(find.text('Server said rate_limited.'), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Message')).controller!.text, 'too fast');
  });

  testWidgets('being removed ends the room with a way back', (tester) async {
    final h = Harness(saved: savedSession());
    h.backend.addRoom(roomJson('r1', 'Garden club', ownerId: 'u-bob'));
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    await tester.tap(find.text('Garden club'));
    await settle(tester);
    await settle(tester);
    h.transport.emit(const Kicked('r1'));
    await settle(tester);
    expect(find.text('You were removed from this room.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'no message box any more');
    await tester.tap(find.text('Back to rooms'));
    await settle(tester);
    expect(find.text('Rooms'), findsOneWidget);
  });

  testWidgets('owner: members sheet can remove someone; owner can close the room', (tester) async {
    final h = Harness(saved: savedSession());
    h.backend.addRoom(roomJson('r1', 'Garden club'));
    h.backend.members['r1']!.add({'id': 'u-bob', 'username': 'bob', 'isOwner': false, 'online': false});
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    await tester.tap(find.text('Garden club'));
    await settle(tester);
    await settle(tester);

    await tester.tap(find.byTooltip('Members'));
    await later(tester);
    expect(find.text('alice (owner)'), findsOneWidget);
    expect(find.byTooltip('Remove bob'), findsOneWidget);
    expect(find.byTooltip('Remove alice'), findsNothing, reason: 'the owner cannot remove themselves');
    await tester.tap(find.byTooltip('Remove bob'));
    await settle(tester);
    expect(h.transport.requests.map((r) => r.$1), contains('room:kick'));
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await later(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await later(tester);
    await tester.tap(find.text('Close the room'));
    await later(tester);
    expect(find.text('Close this room?'), findsOneWidget);
    await tester.tap(find.text('Close room'));
    await settle(tester);
    await settle(tester);
    expect(h.transport.requests.map((r) => r.$1), contains('room:close'));
    expect(find.text('Rooms'), findsOneWidget);
  });

  testWidgets('an expired session in the middle of a chat returns to sign-in with a notice', (tester) async {
    final h = Harness(saved: savedSession());
    h.backend.addRoom(roomJson('r1', 'Garden club'));
    await tester.pumpWidget(h.app);
    await settle(tester);
    await settle(tester);
    await tester.tap(find.text('Garden club'));
    await settle(tester);
    await settle(tester);
    h.transport.emit(const SessionExpired());
    await settle(tester);
    await settle(tester);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('expired'), findsOneWidget);
  });

  testWidgets('screens for the book', (tester) async {
    Future<void> shot(Harness h, String name, Size size, {Future<void> Function(WidgetTester)? after}) =>
        saveScreenshot(
          tester,
          h.app,
          name,
          size: size,
          settle: false,
          beforeCapture: (t) async {
            await settle(t);
            await settle(t);
            if (after != null) await after(t);
            await settle(t);
          },
        );

    await shot(Harness(), 'relay_ch25_signin', const Size(360, 520));

    final lobby = Harness(saved: savedSession());
    lobby.backend
      ..addRoom(roomJson('r1', 'Garden club', members: 3))
      ..addRoom(roomJson('r2', 'Secret plans', isPublic: false, ownerId: 'u-bob', joined: false, invited: true))
      ..addRoom(roomJson('r3', 'Lounge', ownerId: 'u-bob', joined: false, members: 12));
    await shot(lobby, 'relay_ch25_lobby', const Size(360, 520), after: (t) async {
      lobby.transport.emit(const Connected());
    });

    final chat = Harness(saved: savedSession());
    chat.backend.addRoom(roomJson('r1', 'Garden club', members: 2), history: [
      messageJson('r1', 1, 'Is the basil watered?', userId: 'u-bob', username: 'bob'),
      messageJson('r1', 2, 'Yes, this morning.', userId: 'u-alice', username: 'alice'),
      messageJson('r1', 3, 'Great, I will bring seeds on Saturday.', userId: 'u-bob', username: 'bob'),
    ]);
    await shot(chat, 'relay_ch25_room', const Size(360, 520), after: (t) async {
      chat.transport.emit(const Connected());
      await settle(t);
      await t.tap(find.text('Garden club'));
      await settle(t);
      await settle(t);
    });

    final offline = Harness(saved: savedSession());
    offline.backend.addRoom(roomJson('r1', 'Garden club'));
    await shot(offline, 'relay_ch25_offline', const Size(360, 260));
  });
}
