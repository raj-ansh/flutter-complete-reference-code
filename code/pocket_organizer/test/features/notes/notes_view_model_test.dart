import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_organizer/core/result.dart';
import 'package:pocket_organizer/features/notes/note.dart';
import 'package:pocket_organizer/core/list_view_model.dart';
import 'package:pocket_organizer/features/notes/notes_view_model.dart';

import '../../support/capture.dart';
import '../../support/fakes.dart';

void main() {
  late FakeNotesRepository repo;
  late FixedClock clock;
  late NotesViewModel vm;

  setUp(() {
    repo = FakeNotesRepository();
    clock = FixedClock(DateTime.utc(2026, 10, 16, 9));
    vm = NotesViewModel(repo, clock);
  });
  tearDown(() => vm.dispose());

  List<Note> notes() => (vm.state as ListLoaded<Note>).items;

  test('starts loading, then shows what the repository has', () async {
    final seen = <String>[];
    vm.addListener(
      () => seen.add(switch (vm.state) {
        ListLoading() => 'loading',
        ListLoaded() => 'loaded',
        ListFailed() => 'failed',
      }),
    );
    await vm.load();
    expect(seen, ['loading', 'loaded']);
    expect(notes(), isEmpty);
  });

  test(
    'a failing repository leads to ListFailed<Note>, and load() recovers',
    () async {
      repo.failing = true;
      await vm.load();
      expect(vm.state, isA<ListFailed<Note>>());
      repo.failing = false;
      await vm.load();
      expect(vm.state, isA<ListLoaded<Note>>());
    },
  );

  test('save stamps the time from the clock and refreshes the list', () async {
    await vm.load();
    final result = await vm.save(title: 'Milk', body: 'two litres');
    expect(result, isA<Ok<Note>>());
    expect(notes().single.updatedAt, clock.current);

    clock.advance(const Duration(hours: 1));
    await vm.save(existing: notes().single, title: 'Milk and eggs', body: '');
    expect(notes().single.title, 'Milk and eggs');
    expect(notes().single.updatedAt, clock.current);
  });

  test('delete then undo restores the same note, same id', () async {
    await vm.load();
    await vm.save(title: 'Keep', body: 'body');
    final original = notes().single;
    final removed = await vm.delete(original);
    expect(notes(), isEmpty);
    await vm.undoDelete(removed!);
    expect(notes().single.id, original.id);
    expect(notes().single.title, 'Keep');
  });

  test('a failed action keeps the list and reports the problem', () async {
    await vm.load();
    await vm.save(title: 'Stay visible', body: '');
    repo.failing = true;
    await vm.togglePin(notes().single);
    final state = vm.state as ListLoaded<Note>;
    expect(state.items.single.title, 'Stay visible');
    expect(state.message, 'The storage is unavailable');
  });

  test('pinning moves a note to the top', () async {
    await vm.load();
    await vm.save(title: 'first', body: '');
    clock.advance(const Duration(minutes: 1));
    await vm.save(title: 'second', body: '');
    expect(notes().map((n) => n.title), ['second', 'first']);
    await vm.togglePin(notes().last);
    expect(notes().map((n) => n.title), ['first', 'second']);
  });

  test('an old, slow search result cannot overwrite a newer one', () async {
    await vm.load();
    await vm.save(title: 'basil', body: '');
    await vm.save(title: 'banana', body: '');

    // The answer to "ba" is held back until after the answer to "basil".
    final releaseBa = Completer<void>();
    repo.listGate = (query) =>
        query == 'ba' ? releaseBa.future : Future.value();

    final slow = vm.search('ba'); // asked first, answers last
    final fast = vm.search('basil'); // asked second, answers first
    await fast;
    final afterFast = notes().map((n) => n.title).toList();
    releaseBa.complete();
    await slow;
    final afterSlow = notes().map((n) => n.title).toList();
    writeCaptured(
      'po_ch22_stale_search.txt',
      'searched "ba", then "basil"; "ba" answered last\n'
          'after "basil" answered:  $afterFast\n'
          'after "ba" answered:     $afterSlow  (the old answer was ignored)',
    );
    expect(afterSlow, ['basil']);
    expect((vm.state as ListLoaded<Note>).query, 'basil');
  });

  test('find returns the note, or null', () async {
    await vm.load();
    await vm.save(title: 'x', body: '');
    expect(await vm.find(notes().single.id!), isNotNull);
    expect(await vm.find(12345), isNull);
  });
}
