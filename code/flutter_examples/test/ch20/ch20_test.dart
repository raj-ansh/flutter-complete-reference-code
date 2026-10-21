import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_examples/ch20/failure.dart';
import 'package:flutter_examples/ch20/plant.dart';
import 'package:flutter_examples/ch20/plant_api.dart';
import 'package:flutter_examples/ch20/plants_screen.dart';
import 'package:flutter_examples/ch20/retry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

enum Mode {
  ok,
  unauthorized,
  notFound,
  unavailable,
  slow,
  badJson,
  wrongTypes,
  notAnArray,
  textPlain,
}

/// A tiny fake server on localhost, so the client talks to a real socket.
class FakeServer {
  late HttpServer _server;
  Mode mode = Mode.ok;
  int unavailableTimes = 0; // answer 503 this many times, then behave as ok
  final log = <String>[];
  String? lastBody;
  String? lastContentType;

  Uri get uri => Uri.parse('http://127.0.0.1:${_server.port}');

  static const plantsJson = [
    {'id': 1, 'name': 'Gänseblümchen', 'light': 'sun', 'heightCm': 15},
    {'id': 2, 'name': 'Fern', 'light': 'shade', 'heightCm': 60},
  ];

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final res = request.response;
      log.add(
        '${request.method} ${request.uri}  '
        'Accept=${request.headers.value('accept')}  '
        'Authorization=${request.headers.value('authorization') == null ? 'absent' : 'present'}',
      );
      if (request.method == 'POST') {
        lastContentType = request.headers.contentType?.toString();
        lastBody = await utf8.decoder.bind(request).join();
        res.statusCode = 201;
        res.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
        res.add(utf8.encode(lastBody!));
        await res.close();
        return;
      }
      if (unavailableTimes > 0) {
        unavailableTimes--;
        res.statusCode = 503;
        await res.close();
        return;
      }
      switch (mode) {
        case Mode.unauthorized:
          res.statusCode = 401;
        case Mode.notFound:
          res.statusCode = 404;
        case Mode.unavailable:
          res.statusCode = 503;
        case Mode.slow:
          await Future<void>.delayed(const Duration(seconds: 2));
          res.write('[]');
        case Mode.badJson:
          res.headers.contentType = ContentType.json;
          res.write('[{"id": 1, "name": ');
        case Mode.wrongTypes:
          res.headers.contentType = ContentType.json;
          res.write('[{"id": "1", "name": "Fern", "light": "shade"}]');
        case Mode.notAnArray:
          res.headers.contentType = ContentType.json;
          res.write('{"plants": []}');
        case Mode.textPlain:
          res.headers.set('content-type', 'text/plain'); // no charset given
          res.add(utf8.encode(jsonEncode(plantsJson)));
        case Mode.ok:
          res.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
          final page = request.uri.queryParameters['page'];
          if (page == '1') res.headers.set('x-next-page', '2');
          res.add(utf8.encode(jsonEncode(plantsJson)));
      }
      try {
        await res.close();
      } on Object {
        // the client gave up (timeout test)
      }
    });
  }

  Future<void> stop() => _server.close(force: true);
}

String describe(ApiResult<Object?> r) => switch (r) {
  ApiOk(:final value) when value is Paged => 'ApiOk(${value.items.length} plants)',
  ApiOk() => 'ApiOk',
  ApiErr(:final failure) =>
    '${failure.runtimeType}${failure is ServerFailure ? '(${failure.status})' : ''}'
        ' retryable=${failure.retryable}'
        '${failure is BadResponse ? '\n      detail: ${failure.detail}' : ''}',
};

Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 50 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

void main() {
  // flutter_test blocks real sockets by default; this file talks to localhost.
  setUpAll(() => HttpOverrides.global = null);

  late FakeServer server;
  late http.Client client;

  setUp(() async {
    server = FakeServer();
    await server.start();
    client = http.Client();
  });
  tearDown(() async {
    client.close();
    await server.stop();
  });

  PlantApi api({String? token, Duration? timeout}) => PlantApi(
    client: client,
    baseUri: server.uri,
    token: token,
    timeout: timeout ?? const Duration(seconds: 5),
  );

  group('real HTTP against a local server', () {
    test('a GET sends the headers we expect and parses the answer', () async {
      final result = await api(token: 'secret-token').list(page: 1);
      final page = (result as ApiOk<Paged<Plant>>).value;
      writeCaptured(
        'ch20_request.txt',
        'what the server saw:\n  ${server.log.join('\n  ')}\n\n'
            'what the client got:\n'
            '  ${page.items.length} plants: ${page.items.map((p) => p.name).join(', ')}\n'
            '  next page: ${page.nextPage}',
      );
      expect(page.items.first.name, 'Gänseblümchen'); // UTF-8 survived
      expect(page.nextPage, 2);
      expect(server.log.single, contains('Authorization=present'));
      expect(server.log.single, contains('page=1'));
    });

    test('following nextPage until it is null', () async {
      var pageNo = 1;
      var total = 0;
      while (true) {
        final page = ((await api().list(page: pageNo)) as ApiOk<Paged<Plant>>).value;
        total += page.items.length;
        if (page.nextPage == null) break;
        pageNo = page.nextPage!;
      }
      expect(pageNo, 2);
      expect(total, 4);
    });

    test('every kind of failure becomes a typed ApiFailure', () async {
      final rows = StringBuffer();
      Future<void> check(String label, Mode m, {Duration? timeout}) async {
        server.mode = m;
        final r = await api(timeout: timeout).list();
        rows.writeln('${label.padRight(34)}${describe(r)}');
      }

      await check('200 with valid JSON', Mode.ok);
      await check('401 Unauthorized', Mode.unauthorized);
      await check('404 Not Found', Mode.notFound);
      await check('503 Service Unavailable', Mode.unavailable);
      await check('no answer within 300 ms', Mode.slow,
          timeout: const Duration(milliseconds: 300));
      await check('JSON cut off in the middle', Mode.badJson);
      await check('field of the wrong type', Mode.wrongTypes);
      await check('an object instead of an array', Mode.notAnArray);

      final deadUri = server.uri;
      await server.stop(); // now nothing is listening on that port
      final refused = await PlantApi(client: client, baseUri: deadUri).list();
      rows.writeln('${'connection refused'.padRight(34)}${describe(refused)}');
      server = FakeServer()..mode = Mode.ok;
      await server.start(); // so tearDown has something to stop

      writeCaptured('ch20_failures.txt', rows.toString());
      expect(refused, isA<ApiErr<Paged<Plant>>>());
      expect((refused as ApiErr).failure, isA<NoConnection>());
    });

    test('a response labelled text/plain has no charset: decode the bytes', () async {
      server.mode = Mode.textPlain;
      final response = await client.get(server.uri.replace(path: '/plants'));
      final viaBody = (jsonDecode(response.body) as List).first['name'];
      final viaBytes = (jsonDecode(utf8.decode(response.bodyBytes)) as List).first['name'];
      final viaApi = ((await api().list()) as ApiOk<Paged<Plant>>).value.items.first.name;
      writeCaptured(
        'ch20_encoding.txt',
        'Content-Type: ${response.headers['content-type']}\n'
            'response.body  says:                  $viaBody\n'
            'utf8.decode(response.bodyBytes) says: $viaBytes\n'
            'PlantApi (decodes the bytes) says:    $viaApi',
      );
      expect(viaBytes, 'Gänseblümchen');
      expect(viaBody, isNot('Gänseblümchen'));
      expect(viaApi, 'Gänseblümchen');
    });

    test('POST sends JSON with a content type and reads the reply', () async {
      final created = await api().create(
        const Plant(id: 9, name: 'Café palm', light: 'sun', heightCm: 90),
      );
      expect((created as ApiOk<Plant>).value.name, 'Café palm');
      expect(server.lastContentType, 'application/json; charset=utf-8');
      expect(jsonDecode(server.lastBody!), containsPair('name', 'Café palm'));
    });
  });

  group('retry with backoff', () {
    test('retryable failures are retried with doubling delays', () async {
      server.unavailableTimes = 2; // fail twice, then succeed
      final events = <String>[];
      final waits = <Duration>[];
      final result = await withRetry(
        () => api().list(),
        wait: (d) async => waits.add(d), // do not really wait
        onRetry: (attempt, failure, delay) => events.add(
          'attempt $attempt failed with ${failure.runtimeType}; '
          'waiting ${delay.inMilliseconds} ms',
        ),
      );

      server.mode = Mode.notFound;
      var notFoundCalls = 0;
      final notFound = await withRetry(() {
        notFoundCalls++;
        return api().list();
      }, wait: (_) async {});

      server.mode = Mode.unavailable;
      var alwaysDownCalls = 0;
      final alwaysDown = await withRetry(() {
        alwaysDownCalls++;
        return api().list();
      }, wait: (_) async {});

      writeCaptured(
        'ch20_retry.txt',
        'server answers 503, 503, then 200:\n'
            '  ${events.join('\n  ')}\n'
            '  final result: ${describe(result)}\n'
            '\n'
            '404 (not retryable):    $notFoundCalls call(s), ${describe(notFound)}\n'
            '503 forever (4 tries):  $alwaysDownCalls call(s), ${describe(alwaysDown)}',
      );
      expect(waits, [
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1000),
      ]);
      expect(result, isA<ApiOk<Paged<Plant>>>());
      expect(notFoundCalls, 1);
      expect(alwaysDownCalls, 4);
    });
  });

  group('the screen (with a fake client, no network)', () {
    Widget app(http.Client c) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
      home: Scaffold(
        body: PlantsScreen(
          api: PlantApi(client: c, baseUri: Uri.parse('http://example.test')),
        ),
      ),
    );

    MockClient json(String body) => MockClient(
      (request) async => http.Response(
        body,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    testWidgets('loading, then data', (tester) async {
      await tester.pumpWidget(app(json(jsonEncode(FakeServer.plantsJson))));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await waitFor(tester, () => find.text('Fern').evaluate().isNotEmpty);
      expect(find.text('Gänseblümchen'), findsOneWidget);
      expect(find.text('Fern'), findsOneWidget);
    });

    testWidgets('an empty list is its own state', (tester) async {
      await tester.pumpWidget(app(json('[]')));
      await waitFor(
        tester,
        () => find.text('No plants yet').evaluate().isNotEmpty,
      );
      expect(find.text('No plants yet'), findsOneWidget);
    });

    testWidgets('offline shows a message and Try again recovers', (tester) async {
      var online = false;
      final client = MockClient((request) async {
        if (!online) throw const SocketException('Network is unreachable');
        return http.Response(
          jsonEncode(FakeServer.plantsJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await tester.pumpWidget(app(client));
      await waitFor(tester, () => find.text('Try again').evaluate().isNotEmpty);
      expect(find.textContaining('No connection'), findsOneWidget);

      online = true;
      await tester.tap(find.text('Try again'));
      await waitFor(tester, () => find.text('Fern').evaluate().isNotEmpty);
      expect(find.text('Fern'), findsOneWidget);
    });

    testWidgets('screens for the book', (tester) async {
      Future<void> shot(http.Client c, String name, Size size, String wait) =>
          saveScreenshot(
            tester,
            app(c),
            name,
            size: size,
            settle: false,
            beforeCapture: (t) async {
              await waitFor(t, () => find.text(wait).evaluate().isNotEmpty);
              await t.pump();
            },
          );
      await shot(
        json(jsonEncode(FakeServer.plantsJson)),
        'ch20_plants',
        const Size(360, 200),
        'Fern',
      );
      await shot(
        MockClient((r) async => throw const SocketException('unreachable')),
        'ch20_offline',
        const Size(360, 240),
        'Try again',
      );
    });
  });
}
