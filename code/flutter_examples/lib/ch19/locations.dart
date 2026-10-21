import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// #docregion locations
/// Where the app keeps its data on a phone. These calls need a real platform
/// (an emulator or device), so the book's widget tests do not run them.
Future<File> notesJsonFile() async {
  final dir = await getApplicationDocumentsDirectory(); // kept until uninstall
  return File(p.join(dir.path, 'notes.json'));
}

Future<String> notesDatabasePath() async =>
    p.join(await getDatabasesPath(), 'notes.db');

Future<Directory> imageCacheDirectory() =>
    getTemporaryDirectory(); // the system may clear this at any time
// #enddocregion locations
