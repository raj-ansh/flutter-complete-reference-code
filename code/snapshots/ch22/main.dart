import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/clock.dart';
import 'core/database.dart';
import 'features/notes/notes_repository.dart';

// #docregion main
Future<void> main() async {
  // Needed before using plugins (the database) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openOrganizerDatabase(
    databaseFactory,
    p.join(await getDatabasesPath(), 'organizer.db'),
  );
  runApp(
    OrganizerApp(notes: SqliteNotesRepository(db), clock: const SystemClock()),
  );
}
// #enddocregion main
