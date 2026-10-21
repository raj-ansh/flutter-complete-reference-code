import 'package:sqflite/sqflite.dart';

import '../../core/result.dart';
import 'contact.dart';

abstract interface class ContactsRepository {
  /// By name, ignoring case. A non-empty [query] filters by name, phone or
  /// email.
  Future<Result<List<Contact>>> list({String query = ''});
  Future<Result<Contact>> save(Contact contact);
  Future<Result<Contact?>> byId(int id);
  Future<Result<void>> delete(int id);
  Future<Result<Contact>> restore(Contact contact);
}

class SqliteContactsRepository implements ContactsRepository {
  SqliteContactsRepository(this._db);

  final Database _db;

  @override
  Future<Result<List<Contact>>> list({String query = ''}) => _guard(() async {
    final text = query.trim();
    final like = _like(text);
    final rows = await _db.query(
      'contacts',
      where: text.isEmpty ? null : r"(name LIKE ? ESCAPE '\' OR phone LIKE ? ESCAPE '\' OR email LIKE ? ESCAPE '\')",
      whereArgs: text.isEmpty ? null : [like, like, like],
      orderBy: 'name COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(Contact.fromMap).toList();
  }, 'Could not load your contacts');

  @override
  Future<Result<Contact>> save(Contact c) => _guard(() async {
    if (c.id == null) {
      final id = await _db.insert('contacts', c.toMap()..remove('id'));
      return c.copyWith(id: id);
    }
    final changed = await _db.update(
      'contacts',
      c.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [c.id],
    );
    if (changed == 0) throw StateError('Contact ${c.id} no longer exists');
    return c;
  }, 'Could not save the contact');

  @override
  Future<Result<Contact?>> byId(int id) => _guard(() async {
    final rows = await _db.query('contacts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Contact.fromMap(rows.single);
  }, 'Could not open the contact');

  @override
  Future<Result<void>> delete(int id) => _guard(() async {
    await _db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }, 'Could not delete the contact');

  @override
  Future<Result<Contact>> restore(Contact c) => _guard(() async {
    await _db.insert(
      'contacts',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return c;
  }, 'Could not restore the contact');

  static String _like(String text) {
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  Future<Result<T>> _guard<T>(
    Future<T> Function() action,
    String message,
  ) async {
    try {
      return Ok(await action());
    } on Object {
      return Err(message);
    }
  }
}
