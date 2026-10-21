import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pocket_organizer/app.dart';
import 'package:pocket_organizer/core/result.dart';
import 'package:pocket_organizer/features/appointments/appointment.dart';
import 'package:pocket_organizer/features/appointments/appointments_repository.dart';
import 'package:pocket_organizer/features/contacts/contact.dart';
import 'package:pocket_organizer/features/contacts/contacts_repository.dart';
import 'package:pocket_organizer/features/contacts/photos.dart';
import 'package:pocket_organizer/features/tasks/task.dart';
import 'package:pocket_organizer/features/tasks/tasks_repository.dart';

import 'fakes.dart';

/// Shared id and failure handling for the in-memory fakes.
abstract class FakeStore<T> {
  final items = <int, T>{};
  int nextId = 1;

  /// While true every call fails, like a broken disk.
  bool failing = false;

  int? idOf(T item);
  T withId(T item, int id);

  Result<R> fail<R>() => const Err('The storage is unavailable');

  void seed(Iterable<T> initial) {
    for (final item in initial) {
      final id = idOf(item) ?? nextId++;
      if (id >= nextId) nextId = id + 1;
      items[id] = withId(item, id);
    }
  }

  Future<Result<T>> saveItem(T item) async {
    if (failing) return fail();
    final saved = idOf(item) == null ? withId(item, nextId++) : item;
    items[idOf(saved)!] = saved;
    return Ok(saved);
  }

  Future<Result<T?>> byIdItem(int id) async => failing ? fail() : Ok(items[id]);

  Future<Result<void>> deleteItem(int id) async {
    if (failing) return fail();
    items.remove(id);
    return const Ok(null);
  }

  Future<Result<T>> restoreItem(T item) async {
    if (failing) return fail();
    items[idOf(item)!] = item;
    return Ok(item);
  }
}

class FakeTasksRepository extends FakeStore<Task> implements TasksRepository {
  FakeTasksRepository([List<Task> initial = const []]) {
    seed(initial);
  }

  @override
  int? idOf(Task item) => item.id;
  @override
  Task withId(Task item, int id) => item.copyWith(id: id);

  @override
  Future<Result<List<Task>>> list({String query = ''}) async {
    if (failing) return fail();
    final q = query.trim().toLowerCase();
    final tasks =
        items.values
            .where((t) => q.isEmpty || t.title.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) {
            if (a.done != b.done) return a.done ? 1 : -1;
            if (!a.done) {
              if ((a.due == null) != (b.due == null)) {
                return a.due == null ? 1 : -1;
              }
              final byDue = a.due?.compareTo(b.due!) ?? 0;
              if (byDue != 0) return byDue;
            } else {
              final byDone = (b.completedAt ?? DateTime.utc(1970)).compareTo(
                a.completedAt ?? DateTime.utc(1970),
              );
              if (byDone != 0) return byDone;
            }
            return a.id!.compareTo(b.id!);
          });
    return Ok(tasks);
  }

  @override
  Future<Result<Task>> save(Task task) => saveItem(task);
  @override
  Future<Result<Task?>> byId(int id) => byIdItem(id);
  @override
  Future<Result<void>> delete(int id) => deleteItem(id);
  @override
  Future<Result<Task>> restore(Task task) => restoreItem(task);
}

class FakeAppointmentsRepository extends FakeStore<Appointment>
    implements AppointmentsRepository {
  FakeAppointmentsRepository([List<Appointment> initial = const []]) {
    seed(initial);
  }

  @override
  int? idOf(Appointment item) => item.id;
  @override
  Appointment withId(Appointment item, int id) => item.copyWith(id: id);

  @override
  Future<Result<List<Appointment>>> list({String query = ''}) async {
    if (failing) return fail();
    final all = items.values.toList()
      ..sort((a, b) {
        final byTime = a.startsAt.compareTo(b.startsAt);
        return byTime != 0 ? byTime : a.id!.compareTo(b.id!);
      });
    return Ok(all);
  }

  @override
  Future<Result<Appointment>> save(Appointment a) => saveItem(a);
  @override
  Future<Result<Appointment?>> byId(int id) => byIdItem(id);
  @override
  Future<Result<void>> delete(int id) => deleteItem(id);
  @override
  Future<Result<Appointment>> restore(Appointment a) => restoreItem(a);
}

class FakeContactsRepository extends FakeStore<Contact>
    implements ContactsRepository {
  FakeContactsRepository([List<Contact> initial = const []]) {
    seed(initial);
  }

  @override
  int? idOf(Contact item) => item.id;
  @override
  Contact withId(Contact item, int id) => item.copyWith(id: id);

  @override
  Future<Result<List<Contact>>> list({String query = ''}) async {
    if (failing) return fail();
    final q = query.trim().toLowerCase();
    final all =
        items.values
            .where(
              (c) =>
                  q.isEmpty ||
                  c.name.toLowerCase().contains(q) ||
                  c.phone.toLowerCase().contains(q) ||
                  c.email.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) {
            final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return byName != 0 ? byName : a.id!.compareTo(b.id!);
          });
    return Ok(all);
  }

  @override
  Future<Result<Contact>> save(Contact c) => saveItem(c);
  @override
  Future<Result<Contact?>> byId(int id) => byIdItem(id);
  @override
  Future<Result<void>> delete(int id) => deleteItem(id);
  @override
  Future<Result<Contact>> restore(Contact c) => restoreItem(c);
}

// #docregion fakephotos
/// A picker that returns whatever the test tells it to, without a camera.
class FakePhotoPicker implements PhotoPicker {
  /// What the next [pick] returns.
  Result<String?> next = const Ok(null);
  final requests = <PhotoOrigin>[];

  @override
  Future<Result<String?>> pick(PhotoOrigin origin) async {
    requests.add(origin);
    return next;
  }
}

/// Remembers which paths were kept and removed, without touching the disk.
class FakePhotoStorage implements PhotoStorage {
  final kept = <String>[];
  final removed = <String>[];
  bool failToKeep = false;

  @override
  Future<String> keep(String pickedPath) async {
    if (failToKeep) throw const FileSystemException('disk full');
    final target = 'kept/${pickedPath.split('/').last}';
    kept.add(target);
    return target;
  }

  @override
  Future<void> remove(String path) async => removed.add(path);
}
// #enddocregion fakephotos

/// Everything a test needs to start the app: fakes in, handles out.
class TestApp {
  TestApp({
    FakeNotesRepository? notes,
    FakeTasksRepository? tasks,
    FakeAppointmentsRepository? appointments,
    FakeContactsRepository? contacts,
    DateTime? now,
  }) : notes = notes ?? FakeNotesRepository(),
       tasks = tasks ?? FakeTasksRepository(),
       appointments = appointments ?? FakeAppointmentsRepository(),
       contacts = contacts ?? FakeContactsRepository(),
       clock = FixedClock(now ?? DateTime.utc(2026, 10, 16, 9));

  final FakeNotesRepository notes;
  final FakeTasksRepository tasks;
  final FakeAppointmentsRepository appointments;
  final FakeContactsRepository contacts;
  final FixedClock clock;
  final picker = FakePhotoPicker();
  final storage = FakePhotoStorage();

  AppDependencies get dependencies => AppDependencies(
    clock: clock,
    notes: notes,
    tasks: tasks,
    appointments: appointments,
    contacts: contacts,
    photoPicker: picker,
    photoStorage: storage,
  );

  Widget widget({String initialLocation = '/'}) =>
      // A fresh key, so pumping a second app in the same test builds a new
      // State (and new providers and router) instead of reusing the old one.
      OrganizerApp(
        key: UniqueKey(),
        dependencies: dependencies,
        initialLocation: initialLocation,
      );
}
