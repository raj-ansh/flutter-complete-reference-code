import 'package:flutter/foundation.dart';

// #docregion note
/// A note, as the rest of the app sees it. Dates are always UTC.
@immutable
class Note {
  const Note({
    this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    this.pinned = false,
  });

  /// Null until the database assigns one.
  final int? id;
  final String title;
  final String body;
  final DateTime updatedAt;
  final bool pinned;

  /// Storage form: only types a database column can hold. The date becomes
  /// whole milliseconds since 1970 (UTC) and the bool becomes 0 or 1.
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
    'pinned': pinned ? 1 : 0,
  };

  factory Note.fromMap(Map<String, Object?> map) => Note(
    id: map['id'] as int?,
    title: map['title']! as String,
    body: map['body']! as String,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['updated_at']! as int,
      isUtc: true,
    ),
    pinned: (map['pinned'] ?? 0) == 1,
  );

  /// JSON form for file storage and, later, for network transfer.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'pinned': pinned,
  };

  factory Note.fromJson(Map<String, Object?> json) => Note(
    id: json['id'] as int?,
    title: json['title']! as String,
    body: json['body']! as String,
    updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
    pinned: json['pinned'] as bool? ?? false,
  );

  Note copyWith({int? id, String? title, String? body, bool? pinned}) => Note(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    updatedAt: updatedAt,
    pinned: pinned ?? this.pinned,
  );
}
// #enddocregion note

/// The storage contract. Both implementations must pass the same tests.
// #docregion contract
abstract interface class NoteStore {
  Future<Note> add(String title, String body, DateTime now);
  Future<List<Note>> all();
  Future<List<Note>> search(String text);
  Future<bool> delete(int id);
  Future<void> close();
}
// #enddocregion contract
