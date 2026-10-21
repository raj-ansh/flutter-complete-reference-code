import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/clock.dart';
import 'core/database.dart';
import 'features/appointments/appointments_repository.dart';
import 'features/contacts/contacts_repository.dart';
import 'features/contacts/photos.dart';
import 'features/notes/notes_repository.dart';
import 'features/tasks/tasks_repository.dart';

// #docregion main
Future<void> main() async {
  // Needed before using plugins (the database) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  const clock = SystemClock();
  final db = await openOrganizerDatabase(
    databaseFactory,
    p.join(await getDatabasesPath(), 'organizer.db'),
  );
  final documents = await getApplicationDocumentsDirectory();
  runApp(
    OrganizerApp(
      dependencies: AppDependencies(
        clock: clock,
        notes: SqliteNotesRepository(db),
        tasks: SqliteTasksRepository(db),
        appointments: SqliteAppointmentsRepository(db),
        contacts: SqliteContactsRepository(db),
        photoPicker: ImagePickerPhotoPicker(),
        photoStorage: FilePhotoStorage(
          Directory(p.join(documents.path, 'contact_photos')),
          clock,
        ),
      ),
    ),
  );
}
// #enddocregion main
