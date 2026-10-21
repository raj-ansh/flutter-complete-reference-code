import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_organizer/core/database.dart';
import 'package:pocket_organizer/core/list_view_model.dart';
import 'package:pocket_organizer/core/result.dart';
import 'package:pocket_organizer/features/contacts/contact.dart';
import 'package:pocket_organizer/features/contacts/contact_avatar.dart';
import 'package:pocket_organizer/features/contacts/contact_validation.dart';
import 'package:pocket_organizer/features/contacts/contacts_repository.dart';
import 'package:pocket_organizer/features/contacts/contacts_view_model.dart';
import 'package:pocket_organizer/features/contacts/photos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/capture.dart';
import '../../support/fakes.dart';
import '../../support/fakes_more.dart';
import '../../support/screenshot.dart';

void contract(String name, Future<ContactsRepository> Function() create) {
  group('ContactsRepository contract: $name', () {
    late ContactsRepository repo;
    setUp(() async => repo = await create());

    Future<List<String>> names({String query = ''}) async =>
        ((await repo.list(query: query)) as Ok<List<Contact>>).value
            .map((c) => c.name)
            .toList();

    test('sorted by name ignoring case', () async {
      for (final n in ['zoe', 'Adam', 'bella']) {
        await repo.save(Contact(name: n));
      }
      expect(await names(), ['Adam', 'bella', 'zoe']);
    });

    test('search matches name, phone or email', () async {
      await repo.save(const Contact(name: 'Sam', phone: '+44 20 7946 0000'));
      await repo.save(const Contact(name: 'Priya', email: 'priya@example.com'));
      expect(await names(query: 'sam'), ['Sam']);
      expect(await names(query: '7946'), ['Sam']);
      expect(await names(query: 'EXAMPLE.com'), ['Priya']);
    });

    test('the photo path can be set and cleared', () async {
      final saved = ((await repo.save(
        const Contact(name: 'Sam', photoPath: '/data/photo.jpg'),
      )) as Ok<Contact>).value;
      var back = ((await repo.byId(saved.id!)) as Ok<Contact?>).value!;
      expect(back.photoPath, '/data/photo.jpg');
      await repo.save(back.copyWith(photoPath: () => null));
      back = ((await repo.byId(saved.id!)) as Ok<Contact?>).value!;
      expect(back.photoPath, isNull);
    });

    test('delete and restore keep the id', () async {
      final a =
          ((await repo.save(const Contact(name: 'Sam'))) as Ok<Contact>).value;
      await repo.delete(a.id!);
      expect(await names(), isEmpty);
      await repo.restore(a);
      expect(((await repo.byId(a.id!)) as Ok<Contact?>).value!.name, 'Sam');
    });
  });
}

void main() {
  sqfliteFfiInit();

  contract('in-memory fake', () async => FakeContactsRepository());
  contract('SQLite', () async {
    final db = await openOrganizerDatabase(
      databaseFactoryFfi,
      p.join(Directory.systemTemp.createTempSync('contacts_').path, 'c.db'),
    );
    addTearDown(db.close);
    return SqliteContactsRepository(db);
  });

  group('validation', () {
    test('what each validator accepts and says', () {
      final rows = StringBuffer();
      void row(String field, String? input, String? result) => rows.writeln(
        '${field.padRight(7)}${'"${input ?? 'null'}"'.padRight(22)}'
        '${result ?? 'ok'}',
      );
      for (final v in [null, '', '  ', 'Sam', 'x' * 81]) {
        row(
          'name',
          v == null ? null : (v.length > 20 ? '${'x' * 3}…(81 x)' : v),
          validateName(v),
        );
      }
      for (final v in [
        '',
        '+44 20 7946 0000',
        '(020) 7946-0000',
        '12',
        'call me',
        '+++1234',
      ]) {
        row('phone', v, validatePhone(v));
      }
      for (final v in ['', 'a@b.co', 'a@b', '@b.co', 'a b@c.de', 'a@@b.co']) {
        row('email', v, validateEmail(v));
      }
      writeCaptured('po_ch23_validation.txt', rows.toString());

      expect(validateName(''), isNotNull);
      expect(validateName('  '), isNotNull);
      expect(validateName('Sam'), isNull);
      expect(validateName('x' * 81), isNotNull);
      expect(validatePhone(''), isNull);
      expect(validatePhone('+44 20 7946 0000'), isNull);
      expect(validatePhone('(020) 7946-0000'), isNull);
      expect(validatePhone('12'), isNotNull);
      expect(validatePhone('call me'), isNotNull);
      expect(validatePhone('+++1234'), isNotNull);
      expect(validateEmail(''), isNull);
      expect(validateEmail('a@b.co'), isNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail('@b.co'), isNotNull);
      expect(validateEmail('a b@c.de'), isNotNull);
      expect(validateEmail('a@@b.co'), isNotNull);
    });
  });

  group('initials', () {
    test('first and last word, upper case, safe for odd names', () {
      expect(const Contact(name: 'sam').initials, 'S');
      expect(const Contact(name: 'Priya Raman').initials, 'PR');
      expect(const Contact(name: 'Anna Maria Lopez').initials, 'AL');
      expect(const Contact(name: '  ').initials, '?');
      expect(const Contact(name: 'émile zola').initials, 'ÉZ');
      expect(const Contact(name: '😀 Sam').initials.length, greaterThan(1));
    });
  });

  group('view model with a fake picker and storage', () {
    late FakeContactsRepository repo;
    late FakePhotoPicker picker;
    late FakePhotoStorage storage;
    late ContactsViewModel vm;
    setUp(() {
      repo = FakeContactsRepository();
      picker = FakePhotoPicker();
      storage = FakePhotoStorage();
      vm = ContactsViewModel(repo, picker, storage);
    });
    tearDown(() => vm.dispose());

    List<Contact> items() => (vm.state as ListLoaded<Contact>).items;

    test('invalid input is refused before storage is touched', () async {
      await vm.load();
      final r = await vm.save(name: '', phone: '12');
      expect(r, isA<Err<Contact>>());
      expect((r as Err).message, 'Enter a name');
      expect(repo.items, isEmpty);
      expect(await vm.save(name: 'Sam', email: 'nope'), isA<Err<Contact>>());
    });

    test(
      'choosing a photo: cancel, success, denied, storage failure',
      () async {
        picker.next = const Ok(null);
        expect(await vm.choosePhoto(PhotoOrigin.gallery), isA<Ok<String?>>());
        expect((await vm.choosePhoto(PhotoOrigin.gallery) as Ok).value, isNull);
        expect(storage.kept, isEmpty);

        picker.next = const Ok('/tmp/picked.jpg');
        final ok = await vm.choosePhoto(PhotoOrigin.camera);
        expect((ok as Ok<String?>).value, 'kept/picked.jpg');
        expect(picker.requests.last, PhotoOrigin.camera);

        picker.next = const Err('The camera is not available.');
        final denied = await vm.choosePhoto(PhotoOrigin.camera);
        expect((denied as Err).message, 'The camera is not available.');

        picker.next = const Ok('/tmp/other.jpg');
        storage.failToKeep = true;
        final failed = await vm.choosePhoto(PhotoOrigin.gallery);
        expect((failed as Err).message, 'Could not save the photo');
      },
    );

    test('replacing or removing a photo deletes the old file', () async {
      await vm.load();
      await vm.save(name: 'Sam', photoPath: 'kept/one.jpg');
      final sam = items().single;
      await vm.save(existing: sam, name: 'Sam', photoPath: 'kept/two.jpg');
      expect(storage.removed, ['kept/one.jpg']);
      await vm.save(existing: items().single, name: 'Sam', photoPath: null);
      expect(storage.removed, ['kept/one.jpg', 'kept/two.jpg']);
      expect(items().single.photoPath, isNull);
      // Saving without changing the photo removes nothing.
      await vm.save(existing: items().single, name: 'Samuel', photoPath: null);
      expect(storage.removed, hasLength(2));
    });

    test('a failed save keeps the old photo file', () async {
      await vm.load();
      await vm.save(name: 'Sam', photoPath: 'kept/one.jpg');
      repo.failing = true;
      final r = await vm.save(
        existing: items().single,
        name: 'Sam',
        photoPath: 'kept/two.jpg',
      );
      expect(r, isA<Err<Contact>>());
      expect(storage.removed, isEmpty);
    });
  });

  group('FilePhotoStorage on a real folder', () {
    test('keeps a copy under a new name and removes it', () async {
      final dir = Directory.systemTemp.createTempSync('photos_');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // best effort
        }
      });
      final picked = File(p.join(dir.path, 'camera_temp.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final storage = FilePhotoStorage(
        Directory(p.join(dir.path, 'contact_photos')),
        FixedClock(DateTime.utc(2026, 10, 16)),
      );
      final first = await storage.keep(picked.path);
      final second = await storage.keep(picked.path);
      expect(first, isNot(second));
      expect(p.extension(first), '.jpg');
      expect(File(first).readAsBytesSync(), [1, 2, 3]);
      picked.deleteSync(); // the picker's temporary file may vanish
      expect(File(first).existsSync(), isTrue);
      await storage.remove(first);
      expect(File(first).existsSync(), isFalse);
      await storage.remove(first); // removing twice is harmless
      writeCaptured(
        'po_ch23_photo_names.txt',
        'kept as:  ${p.basename(first)}\nand then: ${p.basename(second)}',
      );
    });
  });

  group('screens', () {
    TestApp seeded() => TestApp(
      contacts: FakeContactsRepository(const [
        Contact(
          name: 'Priya Raman',
          phone: '+91 98765 43210',
          email: 'priya@example.com',
        ),
        Contact(name: 'Sam Carter', phone: '020 7946 0000'),
        Contact(name: 'Adam'),
      ]),
    );

    testWidgets('list, search, and the empty state', (tester) async {
      await tester.pumpWidget(TestApp().widget(initialLocation: '/contacts'));
      await tester.pumpAndSettle();
      expect(find.text('No contacts yet'), findsOneWidget);

      await tester.pumpWidget(seeded().widget(initialLocation: '/contacts'));
      await tester.pumpAndSettle();
      final order = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(order, ['Adam', 'Priya Raman', 'Sam Carter']);
      expect(find.text('PR'), findsOneWidget); // initials avatar

      await tester.enterText(find.byType(SearchBar), '7946');
      await tester.pumpAndSettle();
      expect(find.text('Sam Carter'), findsOneWidget);
      expect(find.text('Adam'), findsNothing);
    });

    testWidgets('the form shows each validation message', (tester) async {
      final t = TestApp();
      await tester.pumpWidget(t.widget(initialLocation: '/contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New contact'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);
      expect(t.contacts.items, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'),
        'call me',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'sam@',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Use digits, spaces, dashes and brackets only'),
        findsOneWidget,
      );
      expect(
        find.text('Enter an address like name@example.com'),
        findsOneWidget,
      );
      expect(t.contacts.items, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'),
        '020 7946 0000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'sam@example.com',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(t.contacts.items.values.single.name, 'Sam');
      expect(find.text('Sam'), findsOneWidget); // back on the list
    });

    testWidgets('choosing a photo, then leaving without saving cleans up', (
      tester,
    ) async {
      final t = TestApp();
      t.picker.next = const Ok('/tmp/picked.jpg');
      await tester.pumpWidget(t.widget(initialLocation: '/contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New contact'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from your photos'));
      await tester.pumpAndSettle();
      expect(t.storage.kept, ['kept/picked.jpg']);

      await tester.pageBack(); // leave without saving
      await tester.pumpAndSettle();
      expect(t.storage.removed, ['kept/picked.jpg']);
    });

    testWidgets('an editor opened by a link still closes sensibly', (
      tester,
    ) async {
      final t = TestApp();
      await tester.pumpWidget(t.widget(initialLocation: '/contacts/new'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sam');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      // There was nothing to go back to, so it went to the contacts list.
      expect(find.text('Contacts'), findsWidgets);
      expect(find.byType(SearchBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refused camera is explained, not a crash', (tester) async {
      final t = TestApp();
      t.picker.next = const Err(
        'The camera is not available. Check the app\'s camera permission.',
      );
      await tester.pumpWidget(t.widget(initialLocation: '/contacts/new'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('camera is not available'), findsOneWidget);
    });

    testWidgets('the avatar decodes a photo no larger than it draws', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactAvatar(
              contact: Contact(name: 'Sam', photoPath: '/no/such/file.jpg'),
              radius: 20,
            ),
          ),
        ),
      );
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      final image = avatar.foregroundImage! as ResizeImage;
      final ratio = tester.view.devicePixelRatio;
      expect(image.width, (20 * 2 * ratio).round()); // diameter in real pixels
      expect(find.text('S'), findsOneWidget); // initials stay as the fallback
    });

    testWidgets('screens for the book', (tester) async {
      await saveScreenshot(
        tester,
        seeded().widget(initialLocation: '/contacts'),
        'po_ch23_contacts',
        size: const Size(360, 520),
      );
      await saveScreenshot(
        tester,
        TestApp().widget(initialLocation: '/contacts/new'),
        'po_ch23_contact_form',
        size: const Size(360, 520),
        beforeCapture: (t) async {
          await t.enterText(
            find.widgetWithText(TextFormField, 'Name'),
            'Priya Raman',
          );
          await t.enterText(
            find.widgetWithText(TextFormField, 'Phone'),
            'call me',
          );
          await t.tap(find.text('Save'));
          await t.pumpAndSettle();
        },
      );
    });
  });
}
