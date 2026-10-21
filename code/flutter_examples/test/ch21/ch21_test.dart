import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_examples/ch21/chat_screen.dart';
import 'package:flutter_examples/ch21/chat_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

/// Runs the Node server from `book/code/realtime_demo` as a child process.
class NodeServer {
  NodeServer._(this._process, this.port);
  final Process _process;
  final int port;

  String get url => 'http://127.0.0.1:$port';

  static Future<NodeServer> start({int port = 0}) async {
    final process = await Process.start('node', [
      'server.js',
      '$port',
    ], workingDirectory: '../realtime_demo');
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final first = await lines.firstWhere((l) => l.startsWith('PORT='));
    process.stderr.drain<void>();
    return NodeServer._(process, int.parse(first.substring(5)));
  }

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
  }
}

Future<T> firstOf<T extends ChatEvent>(Stream<ChatEvent> s, {int secs = 10}) =>
    s.where((e) => e is T).cast<T>().first.timeout(Duration(seconds: secs));

void main() {
  setUpAll(() => HttpOverrides.global = null); // real sockets to localhost

  group('against the real Node server', () {
    late NodeServer server;
    final transports = <SocketIoTransport>[];

    setUp(() async => server = await NodeServer.start());
    tearDown(() async {
      for (final t in transports) {
        t.dispose();
      }
      transports.clear();
      await server.stop();
    });

    SocketIoTransport client({int reconnectMs = 500}) {
      final t = SocketIoTransport(server.url, reconnectDelayMs: reconnectMs);
      transports.add(t);
      return t;
    }

    test('what Socket.IO looks like on the wire', () async {
      // 1. The HTTP long-polling handshake.
      final handshake = await http.get(
        Uri.parse('${server.url}/socket.io/?EIO=4&transport=polling'),
      );
      final body = handshake.body.replaceAllMapped(
        RegExp(r'"sid":"[^"]+"'),
        (_) => '"sid":"<random id>"',
      );

      // 2. A plain WebSocket client on the Socket.IO endpoint.
      final channel = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/socket.io/?EIO=4&transport=websocket'),
      );
      await channel.ready;
      final frames = <String>[];
      final sub = channel.stream.listen((f) => frames.add('$f'));
      channel.sink.add('hello from a plain WebSocket client');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await sub.cancel();
      await channel.sink.close();
      final framesText = frames
          .map((f) => f.replaceAllMapped(RegExp(r'"sid":"[^"]+"'), (_) => '"sid":"<random id>"'))
          .join('\n  ');

      // 3. A plain WebSocket client on the wrong path.
      String wrongPath;
      try {
        final bad = WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/'));
        await bad.ready.timeout(const Duration(seconds: 3));
        wrongPath = 'connected';
        await bad.sink.close();
      } on Object catch (e) {
        wrongPath = e.runtimeType.toString();
      }

      writeCaptured(
        'ch21_wire.txt',
        'GET /socket.io/?EIO=4&transport=polling  ->  ${handshake.statusCode}\n'
            '  $body\n'
            '\n'
            'plain WebSocket client on /socket.io/ received these frames:\n'
            '  $framesText\n'
            '  (it sent "hello from a plain WebSocket client"; nothing came back)\n'
            '\n'
            'plain WebSocket client on / ->  $wrongPath',
      );
      expect(handshake.statusCode, 200);
      expect(body, contains('"upgrades":["websocket"]'));
      expect(frames.first, startsWith('0{'));
      expect(frames.length, 1);
    });

    test('connect, send, acknowledgement, and a second client hears it', () async {
      final a = client();
      final b = client();
      final timeline = <String>[];
      a.events.listen((e) => timeline.add('A: ${describeEvent(e)}'));
      b.events.listen((e) => timeline.add('B: ${describeEvent(e)}'));
      final connectedA = firstOf<Connected>(a.events);
      final connectedB = firstOf<Connected>(b.events);
      a.connect();
      b.connect();
      await connectedA;
      await connectedB;
      expect(a.isConnected, isTrue);

      final heardByB = firstOf<MessageReceived>(b.events);
      final result = await a.send('  Hello, Relay!  ');
      final heard = await heardByB;
      timeline.add('A: send() returned ${describeResult(result)}');
      writeCaptured(
        'ch21_timeline.txt',
        'both clients connect, then A sends "  Hello, Relay!  ":\n'
            '${timeline.map((l) => '  $l').join('\n')}',
      );
      expect(result, isA<Sent>());
      expect(heard.message.text, 'Hello, Relay!'); // the server trimmed it
    });

    test('the server validates, and says why in the acknowledgement', () async {
      final a = client();
      final connected = firstOf<Connected>(a.events);
      a.connect();
      await connected;
      final empty = await a.send('   ');
      final tooLong = await a.send('x' * 201);
      final ok = await a.send('x' * 200);
      writeCaptured(
        'ch21_validation.txt',
        'send("   "):        ${describeResult(empty)}\n'
            'send(201 chars):    ${describeResult(tooLong)}\n'
            'send(200 chars):    ${describeResult(ok)}',
      );
      expect(empty, isA<Rejected>());
      expect(tooLong, isA<Rejected>());
      expect(ok, isA<Sent>());
    });

    test('an emit without an acknowledgement does not break the server', () async {
      final raw = io.io(
        server.url,
        io.OptionBuilder().setTransports(['websocket']).enableForceNew().build(),
      );
      final connected = Completer<void>();
      raw.onConnect((_) => connected.complete());
      await connected.future.timeout(const Duration(seconds: 5));
      raw.emit('chat:send', {'text': 'no callback'});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      raw.dispose();

      final a = client();
      final c = firstOf<Connected>(a.events);
      a.connect();
      await c;
      expect(await a.send('still alive'), isA<Sent>());
    });

    test('rooms: only members may speak, only members hear', () async {
      io.Socket make() => io.io(
        server.url,
        io.OptionBuilder().setTransports(['websocket']).enableForceNew().build(),
      );
      final alice = make();
      final bob = make();
      final carol = make();
      addTearDown(() {
        alice.dispose();
        bob.dispose();
        carol.dispose();
      });
      for (final s in [alice, bob, carol]) {
        final c = Completer<void>();
        s.onConnect((_) => c.isCompleted ? null : c.complete());
        await c.future.timeout(const Duration(seconds: 5));
      }
      Future<Object?> ask(io.Socket s, String event, Object? data) {
        final c = Completer<Object?>();
        s.emitWithAck(event, data, ack: (Object? r) => c.complete(r));
        return c.future.timeout(const Duration(seconds: 5));
      }

      final heard = <String>[];
      for (final (name, s) in [('alice', alice), ('bob', bob), ('carol', carol)]) {
        s.on('room:message', (m) => heard.add('$name heard "${(m as Map)['text']}"'));
      }
      final joinA = await ask(alice, 'room:join', 'garden');
      final joinB = await ask(bob, 'room:join', 'garden');
      final badName = await ask(carol, 'room:join', 'Not Valid!');
      final outsider = await ask(carol, 'room:send', {'room': 'garden', 'text': 'let me in'});
      final member = await ask(alice, 'room:send', {'room': 'garden', 'text': 'water the basil'});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      heard.sort();
      writeCaptured(
        'ch21_rooms.txt',
        'alice joins "garden":           $joinA\n'
            'bob joins "garden":             $joinB\n'
            'carol joins "Not Valid!":       $badName\n'
            'carol (not a member) sends:     $outsider\n'
            'alice (member) sends:           $member\n'
            'who received the room message:  ${heard.join('; ')}',
      );
      expect(heard, ['alice heard "water the basil"', 'bob heard "water the basil"']);
      expect((outsider as Map)['ok'], false);
    });

    test('losing the server, reconnecting, and the offline-send policy', () async {
      final a = client();
      final timeline = <String>[];
      a.events.listen((e) {
        if (e is! MessageReceived) timeline.add(describeEvent(e));
      });
      final first = firstOf<Connected>(a.events);
      a.connect();
      await first;
      final port = server.port;

      final lost = firstOf<Disconnected>(a.events);
      await server.stop();
      await lost;
      final offlineSend = await a.send('typed while offline');
      timeline.add('send() while offline: ${describeResult(offlineSend)}');

      final back = firstOf<Connected>(a.events, secs: 20);
      server = await NodeServer.start(port: port);
      timeline.add('(server restarted on the same port)');
      await back;
      final afterSend = await a.send('after reconnect');
      timeline.add('send() after reconnect: ${describeResult(afterSend)}');

      writeCaptured(
        'ch21_reconnect.txt',
        'event order seen by the client (the server was stopped, then restarted):\n'
            '${timeline.map((l) => '  $l').join('\n')}',
      );
      expect(offlineSend, isA<SendFailed>());
      expect(afterSend, isA<Sent>());
      expect(timeline.first, 'Connected');
      expect(timeline[1], startsWith('Disconnected'));
    });
  });

  group('the screen, with a fake transport', () {
    Widget app(ChatTransport t) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
      home: Scaffold(body: ChatScreen(transport: t)),
    );

    testWidgets('status, messages and send errors are shown', (tester) async {
      final fake = FakeTransport();
      await tester.pumpWidget(app(fake));
      expect(find.text('Connecting…'), findsOneWidget);
      expect(fake.connectCalls, 1);

      await deliver(tester, fake, const Connected());
      expect(find.text('Connected'), findsOneWidget);

      await deliver(
        tester,
        fake,
        MessageReceived(
          ChatMessage(id: 1, from: 'ab12c', text: 'Hi there', at: DateTime.utc(2026)),
        ),
      );
      expect(find.text('Hi there'), findsOneWidget);

      fake.nextResult = const Rejected('text must be 1 to 200 characters');
      await tester.enterText(find.byType(TextField), 'x');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(find.textContaining('Not sent: text must be'), findsOneWidget);
      expect(find.text('x'), findsOneWidget); // kept so the user can fix it

      fake.nextResult = const Sent(2);
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(find.textContaining('Not sent'), findsNothing);

      await deliver(tester, fake, const Disconnected('transport close'));
      expect(find.textContaining('Offline'), findsOneWidget);
    });

    testWidgets('events after the screen is gone are ignored', (tester) async {
      final fake = FakeTransport();
      await tester.pumpWidget(app(fake));
      await tester.pumpWidget(const SizedBox());
      fake.emit(const Connected()); // would call setState on a dead State
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(fake.hasListener, isFalse);
    });

    testWidgets('screens for the book', (tester) async {
      final fake = FakeTransport();
      await saveScreenshot(
        tester,
        app(fake),
        'ch21_chat',
        size: const Size(360, 360),
        beforeCapture: (t) async {
          await deliver(t, fake, const Connected());
          for (final (i, text) in ['Is the basil watered?', 'Yes, this morning.'].indexed) {
            await deliver(
              t,
              fake,
              MessageReceived(
                ChatMessage(id: i, from: i == 0 ? 'ab12c' : 'zz9y8', text: text, at: DateTime.utc(2026)),
              ),
            );
          }
        },
      );
      final offline = FakeTransport();
      await saveScreenshot(
        tester,
        app(offline),
        'ch21_chat_offline',
        size: const Size(360, 160),
        beforeCapture: (t) async {
          await deliver(t, offline, const Disconnected('transport close'));
        },
      );
    });
  });
}

/// A stream delivers its events in a later microtask, so a single pump may
/// run before the widget has even heard the event. Pump twice.
Future<void> deliver(WidgetTester t, FakeTransport f, ChatEvent e) async {
  f.emit(e);
  await t.pump();
  await t.pump();
}

String describeEvent(ChatEvent e) => switch (e) {
  Connected() => 'Connected',
  Disconnected(:final reason) => 'Disconnected ($reason)',
  ConnectFailed() => 'ConnectFailed',
  MessageReceived(:final message) => 'MessageReceived("${message.text}")',
};

String describeResult(SendResult r) => switch (r) {
  Sent(:final id) => 'Sent(id: $id)',
  Rejected(:final reason) => 'Rejected("$reason")',
  SendFailed(:final reason) => 'SendFailed("$reason")',
};

class FakeTransport implements ChatTransport {
  final _controller = StreamController<ChatEvent>.broadcast();
  int connectCalls = 0;
  SendResult nextResult = const Sent(1);

  @override
  Stream<ChatEvent> get events => _controller.stream;
  @override
  bool get isConnected => true;
  @override
  void connect() => connectCalls++;
  @override
  Future<SendResult> send(String text) async => nextResult;
  @override
  void dispose() => _controller.close();

  bool get hasListener => _controller.hasListener;
  void emit(ChatEvent e) => _controller.add(e);
}
