import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:relay_app/core/result.dart';
import 'package:relay_app/data/models.dart';
import 'package:relay_app/data/relay_api.dart';
import 'package:relay_app/data/relay_service.dart';
import 'package:relay_app/data/transport.dart';
import 'package:relay_app/state/session_view_model.dart';

import 'support/capture.dart';
import 'support/fakes.dart';

void main() {
  group('server address', () {
    test('what is accepted, what is cleaned, what is refused', () {
      final rows = StringBuffer();
      for (final input in [
        'http://10.0.2.2:3000',
        '10.0.2.2:3000',
        '  https://chat.example.com/  ',
        'http://localhost:3000/api/login?x=1',
        'chat.example.com',
        '',
        '   ',
        'ftp://example.com',
        'http://',
        'http://exa mple.com',
      ]) {
        final r = parseServerUrl(input);
        rows.writeln(
          '${'"$input"'.padRight(40)}${switch (r) {
            Ok(:final value) => '-> $value',
            Err(:final message) => 'refused: $message',
          }}',
        );
      }
      writeCaptured('relay_ch25_server_url.txt', rows.toString());

      expect((parseServerUrl('10.0.2.2:3000') as Ok<Uri>).value.toString(), 'http://10.0.2.2:3000');
      expect((parseServerUrl('http://localhost:3000/api/login?x=1') as Ok<Uri>).value.toString(), 'http://localhost:3000');
      expect((parseServerUrl('  https://chat.example.com/  ') as Ok<Uri>).value.toString(), 'https://chat.example.com');
      for (final bad in ['', '   ', 'ftp://example.com', 'http://', 'http://exa mple.com']) {
        expect(parseServerUrl(bad), isA<Err<Uri>>(), reason: bad);
      }
    });
  });

  group('server replies', () {
    test('parseReply understands the two shapes and rejects the rest', () {
      final rows = StringBuffer();
      String show(Object? reply) {
        final r = parseReply(reply);
        final text = switch (r) {
          Ok(:final value) => 'Ok(${value.keys.join(', ')})',
          Err(:final code, :final message) => 'Err($code: $message)',
        };
        rows.writeln('${'$reply'.padRight(58)}$text');
        return text;
      }

      expect(show({'ok': true, 'rooms': []}), 'Ok(ok, rooms)');
      expect(show({'ok': false, 'code': 'forbidden', 'message': 'No.'}), 'Err(forbidden: No.)');
      for (final bad in [null, 'text', 42, [], {'ok': false}, {'ok': 'yes'}, {'code': 'x', 'message': 'y'}, {'ok': false, 'code': 1, 'message': 2}]) {
        expect(show(bad), startsWith('Err(bad_response'), reason: '$bad');
      }
      writeCaptured('relay_ch25_replies.txt', rows.toString());
    });
  });

  group('models are parsed strictly', () {
    test('a good room parses; wrong or missing fields are a FormatException', () {
      expect(RoomSummary.fromJson(roomJson('r1', 'Garden')).name, 'Garden');
      final good = roomJson('r1', 'Garden');
      final problems = StringBuffer();
      for (final key in good.keys) {
        final broken = Map.of(good)..remove(key);
        expect(() => RoomSummary.fromJson(broken), throwsFormatException, reason: 'missing $key');
      }
      final wrongType = Map.of(good)..['memberCount'] = '3';
      expect(() => RoomSummary.fromJson(wrongType), throwsFormatException);
      expect(() => RoomSummary.fromJson('not a map'), throwsFormatException);
      expect(() => RoomSummary.fromJson(null), throwsFormatException);
      try {
        RoomSummary.fromJson(wrongType);
      } on FormatException catch (e) {
        problems.writeln(e.message.length > 60 ? '${e.message.substring(0, 60)}…' : e.message);
      }
      expect(problems.toString(), startsWith('Not a room'));
    });

    test('messages carry a UTC time', () {
      final m = ChatMessage.fromJson(messageJson('r1', 3, 'hi'));
      expect(m.at.isUtc, isTrue);
      expect(m.seq, 3);
    });
  });

  group('RelayApi (fake HTTP)', () {
    RelayApi apiFor(http.Client c) => RelayApi(client: c, baseUri: Uri.parse('http://server.test:3000'));

    test('sign in, sign up, and each way it can fail', () async {
      final rows = StringBuffer();
      Future<Result<Session>> run(String label, Future<Result<Session>> r) async {
        final result = await r;
        rows.writeln('${label.padRight(32)}${switch (result) {
          Ok(:final value) => 'Ok(${value.user.username})',
          Err(:final code, :final message) => '$code: $message',
        }}');
        return result;
      }

      final api = apiFor(authClient(taken: {'sam'}));
      expect(await run('sign in, right password', api.login('alice', 'a long enough password')), isA<Ok<Session>>());
      final wrong = await run('sign in, wrong password', api.login('alice', 'nope'));
      expect((wrong as Err).code, 'unauthorized');
      final taken = await run('sign up, name taken', api.register('Sam', 'a long enough password'));
      expect((taken as Err).code, 'conflict');
      expect(await run('sign up, new name', api.register('Newbie', 'a long enough password')), isA<Ok<Session>>());

      Future<Result<Session>> viaClient(http.Client c) => apiFor(c).login('a', 'b');
      final offline = await run('server unreachable', viaClient(MockClient((_) async => throw http.ClientException('refused'))));
      expect((offline as Err).code, 'network');
      final html = await run('server sends HTML, not JSON', viaClient(MockClient((_) async => http.Response('<html>502</html>', 502))));
      expect((html as Err).code, 'bad_response');
      final odd = await run('JSON of the wrong shape', viaClient(MockClient((_) async => http.Response('{"ok":true,"user":5}', 200))));
      expect((odd as Err).code, 'bad_response');
      final limited = await run(
        'rate limited by the server',
        viaClient(MockClient((_) async => http.Response('{"ok":false,"code":"rate_limited","message":"Too many attempts."}', 429))),
      );
      expect((limited as Err).code, 'rate_limited');
      writeCaptured('relay_ch25_api.txt', rows.toString());
    });

    test('logout never throws, even offline', () async {
      await apiFor(MockClient((_) async => throw http.ClientException('down'))).logout('t');
    });
  });

  group('RelayService over a fake transport', () {
    late FakeTransport transport;
    late RelayService service;
    setUp(() {
      transport = FakeTransport();
      service = RelayService(transport);
    });

    test('sends the event the server expects and parses the answer', () async {
      transport.onRequest = (event, payload) => switch (event) {
        'rooms:list' => Ok({'ok': true, 'rooms': [roomJson('r1', 'Garden')]}),
        'room:create' => Ok({'ok': true, 'room': roomJson('r2', payload['name']! as String, isPublic: payload['isPublic']! as bool)}),
        'room:history' => Ok({'ok': true, 'messages': [messageJson('r1', 1, 'hi')]}),
        _ => null,
      };
      expect(((await service.listRooms()) as Ok<List<RoomSummary>>).value.single.name, 'Garden');
      final created = (await service.createRoom('Club', isPublic: false)) as Ok<RoomSummary>;
      expect(created.value.isPublic, isFalse);
      expect(transport.requests.last.$1, 'room:create');
      expect(transport.requests.last.$2, equals({'name': 'Club', 'isPublic': false}));
      await service.history('r1', afterSeq: 7);
      expect(transport.requests.last.$2, equals({'roomId': 'r1', 'afterSeq': 7}));
      await service.history('r1');
      expect(transport.requests.last.$2.containsKey('afterSeq'), isFalse); // omitted, not null
    });

    test('server errors pass through; damaged answers become bad_response', () async {
      transport.onRequest = (event, _) => const Err('forbidden', 'Only the room owner can do that.');
      final refused = await service.kick('r1', 'bob');
      expect((refused as Err).code, 'forbidden');

      transport.onRequest = (event, _) => Ok({'ok': true, 'rooms': 'not a list'});
      expect(((await service.listRooms()) as Err).code, 'bad_response');
      transport.onRequest = (event, _) => Ok({'ok': true, 'rooms': [{'id': 1}]});
      expect(((await service.listRooms()) as Err).code, 'bad_response');
      transport.onRequest = (event, _) => Ok({'ok': true});
      expect(((await service.send('r1', 'x')) as Err).code, 'bad_response');
    });
  });
}
