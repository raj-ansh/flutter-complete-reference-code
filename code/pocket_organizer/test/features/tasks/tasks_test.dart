import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_organizer/core/calendar_date.dart';
import 'package:pocket_organizer/core/database.dart';
import 'package:pocket_organizer/core/list_view_model.dart';
import 'package:pocket_organizer/core/result.dart';
import 'package:pocket_organizer/features/tasks/task.dart';
import 'package:pocket_organizer/features/tasks/task_groups.dart';
import 'package:pocket_organizer/features/tasks/tasks_repository.dart';
import 'package:pocket_organizer/features/tasks/tasks_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/capture.dart';
import '../../support/fakes.dart';
import '../../support/fakes_more.dart';
import '../../support/screenshot.dart';

const today = CalendarDate(2026, 10, 16);

Task task(String title, {CalendarDate? due, bool done = false, DateTime? at}) =>
    Task(title: title, due: due, done: done, completedAt: at);

void contract(String name, Future<TasksRepository> Function() create) {
  group('TasksRepository contract: $name', () {
    late TasksRepository repo;
    setUp(() async => repo = await create());

    Future<List<String>> titles({String query = ''}) async =>
        ((await repo.list(query: query)) as Ok<List<Task>>).value
            .map((t) => t.title)
            .toList();

    test(
      'open tasks by due date with undated last, then finished ones',
      () async {
        await repo.save(task('later', due: const CalendarDate(2026, 12, 1)));
        await repo.save(task('undated'));
        await repo.save(task('soon', due: const CalendarDate(2026, 10, 17)));
        await repo.save(
          task('finished early', done: true, at: DateTime.utc(2026, 10, 1)),
        );
        await repo.save(
          task('finished late', done: true, at: DateTime.utc(2026, 10, 15)),
        );
        expect(await titles(), [
          'soon',
          'later',
          'undated',
          'finished late',
          'finished early',
        ]);
      },
    );

    test(
      'the due day survives a round trip as a day, not an instant',
      () async {
        final saved = ((await repo.save(
          task('x', due: const CalendarDate(2026, 3, 29)),
        )) as Ok<Task>).value;
        final back = ((await repo.byId(saved.id!)) as Ok<Task?>).value!;
        expect(back.due, const CalendarDate(2026, 3, 29));
      },
    );

    test('clearing the due date and finishing a task are saved', () async {
      final saved = ((await repo.save(
        task('x', due: const CalendarDate(2026, 3, 29)),
      )) as Ok<Task>).value;
      await repo.save(saved.copyWith(due: () => null));
      var back = ((await repo.byId(saved.id!)) as Ok<Task?>).value!;
      expect(back.due, isNull);
      await repo.save(
        back.copyWith(done: true, completedAt: () => DateTime.utc(2026, 10, 1)),
      );
      back = ((await repo.byId(saved.id!)) as Ok<Task?>).value!;
      expect(back.done, isTrue);
      expect(back.completedAt, DateTime.utc(2026, 10, 1));
    });

    test('search by title; delete and restore keep the id', () async {
      final a = ((await repo.save(task('Buy basil'))) as Ok<Task>).value;
      await repo.save(task('Call Sam'));
      expect(await titles(query: 'BASIL'), ['Buy basil']);
      await repo.delete(a.id!);
      expect(await titles(), ['Call Sam']);
      await repo.restore(a);
      expect(((await repo.byId(a.id!)) as Ok<Task?>).value!.title, 'Buy basil');
    });
  });
}

void main() {
  sqfliteFfiInit();

  contract('in-memory fake', () async => FakeTasksRepository());
  contract('SQLite', () async {
    final db = await openOrganizerDatabase(
      databaseFactoryFfi,
      p.join(Directory.systemTemp.createTempSync('tasks_').path, 't.db'),
    );
    addTearDown(db.close);
    return SqliteTasksRepository(db);
  });

  group('sections', () {
    test('a task belongs to exactly the section its day and state say', () {
      final yesterday = today.addDays(-1);
      final cases = <String, (Task, TaskSection)>{
        'due yesterday': (task('a', due: yesterday), TaskSection.overdue),
        'due today': (task('b', due: today), TaskSection.today),
        'due tomorrow': (
          task('c', due: today.addDays(1)),
          TaskSection.upcoming,
        ),
        'no due date': (task('d'), TaskSection.noDate),
        'done, was overdue': (
          task('e', due: yesterday, done: true),
          TaskSection.done,
        ),
        'done, no date': (task('f', done: true), TaskSection.done),
      };
      final rows = StringBuffer('today is $today\n');
      cases.forEach((label, c) {
        final got = sectionOf(c.$1, today);
        rows.writeln('${label.padRight(20)} -> ${got.title}');
        expect(got, c.$2, reason: label);
      });
      writeCaptured('po_ch23_sections.txt', rows.toString());
    });

    test('groupTasks keeps the display order and drops empty sections', () {
      final groups = groupTasks([
        task('done', done: true),
        task('late', due: today.addDays(-3)),
        task('now', due: today),
      ], today);
      expect(groups.map((g) => g.$1), [
        TaskSection.overdue,
        TaskSection.today,
        TaskSection.done,
      ]);
    });
  });

  group('copyWith with nullable fields', () {
    test('omitting keeps, () => null clears', () {
      final t = task('x', due: today, done: true, at: DateTime.utc(2026));
      expect(t.copyWith(title: 'y').due, today);
      expect(t.copyWith(due: () => null).due, isNull);
      expect(t.copyWith(completedAt: () => null).completedAt, isNull);
      expect(t.copyWith(title: 'y').completedAt, DateTime.utc(2026));
    });
  });

  group('view model', () {
    late FakeTasksRepository repo;
    late FixedClock clock;
    late TasksViewModel vm;
    setUp(() {
      repo = FakeTasksRepository();
      clock = FixedClock(DateTime.utc(2026, 10, 16, 9));
      vm = TasksViewModel(repo, clock);
    });
    tearDown(() => vm.dispose());

    List<Task> items() => (vm.state as ListLoaded<Task>).items;

    test('ticking records the time; un-ticking forgets it', () async {
      await vm.load();
      await vm.save(title: '  Water the fern  ', due: today);
      expect(items().single.title, 'Water the fern'); // trimmed
      await vm.toggleDone(items().single);
      expect(items().single.done, isTrue);
      expect(items().single.completedAt, clock.current);
      await vm.toggleDone(items().single);
      expect(items().single.done, isFalse);
      expect(items().single.completedAt, isNull);
    });

    test('editing a task can clear its due date', () async {
      await vm.load();
      await vm.save(title: 'x', due: today);
      await vm.save(existing: items().single, title: 'x', due: null);
      expect(items().single.due, isNull);
    });

    test('delete and undo; failure keeps the list', () async {
      await vm.load();
      await vm.save(title: 'keep');
      final removed = await vm.delete(items().single);
      expect(items(), isEmpty);
      await vm.undoDelete(removed!);
      expect(items().single.title, 'keep');
      repo.failing = true;
      await vm.toggleDone(items().single);
      final state = vm.state as ListLoaded<Task>;
      expect(state.items.single.title, 'keep');
      expect(state.message, isNotNull);
    });
  });

  group('screen', () {
    Widget app(TestApp t) => t.widget(initialLocation: '/tasks');

    TestApp seeded() => TestApp(
      tasks: FakeTasksRepository([
        task('Pay the bill', due: today.addDays(-2)),
        task('Water the fern', due: today),
        task('Book a dentist', due: today.addDays(5)),
        task('Read a book'),
        task('Buy basil', done: true, at: DateTime.utc(2026, 10, 15)),
      ]),
    );

    testWidgets('sections, ticking, and the empty state', (tester) async {
      await tester.pumpWidget(app(TestApp()));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to do'), findsOneWidget);

      await tester.pumpWidget(app(seeded()));
      await tester.pumpAndSettle();
      for (final header in [
        'Overdue',
        'Today',
        'Upcoming',
        'No date',
        'Done',
      ]) {
        // "Today" is also the due label of one task, so it may appear twice.
        expect(find.text(header), findsWidgets, reason: header);
      }
      await tester.tap(find.text('Water the fern'));
      await tester.pumpAndSettle();
      // Today's section is now empty, so its header is gone; only the done
      // task's own "Today" due label is left.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Water the fern'), findsOneWidget);
    });

    testWidgets('add a task with a due date through the sheet', (tester) async {
      final t = TestApp();
      await tester.pumpWidget(app(t));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New task'));
      await tester.pumpAndSettle();

      // Saving an empty name is refused.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Give the task a name'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Task'),
        'Pack bags',
      );
      await tester.tap(find.text('Add a due date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // accept the picker's initial day
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Pack bags'), findsOneWidget);
      expect(find.text('Today'), findsWidgets); // header and the due label
      final saved = t.tasks.items.values.single;
      expect(saved.due, CalendarDate.fromDateTime(t.clock.now().toLocal()));
    });

    testWidgets('swipe to delete and Undo', (tester) async {
      await tester.pumpWidget(app(seeded()));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Read a book'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Read a book'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Read a book'), findsOneWidget);
    });

    testWidgets('screens for the book', (tester) async {
      await saveScreenshot(
        tester,
        app(seeded()),
        'po_ch23_tasks',
        size: const Size(360, 640),
      );
      await saveScreenshot(
        tester,
        app(seeded()),
        'po_ch23_task_sheet',
        size: const Size(360, 520),
        beforeCapture: (t) async {
          await t.tap(find.byTooltip('New task'));
          await t.pumpAndSettle();
          await t.enterText(
            find.widgetWithText(TextField, 'Task'),
            'Pack bags',
          );
          await t.pumpAndSettle();
        },
      );
    });
  });
}
