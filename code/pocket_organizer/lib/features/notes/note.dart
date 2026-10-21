import 'package:flutter/foundation.dart';

// #docregion note
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

  /// UTC instant of the last change.
  final DateTime updatedAt;
  final bool pinned;

  Note copyWith({
    int? id,
    String? title,
    String? body,
    DateTime? updatedAt,
    bool? pinned,
  }) => Note(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    updatedAt: updatedAt ?? this.updatedAt,
    pinned: pinned ?? this.pinned,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'pinned': pinned ? 1 : 0,
    'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
  };

  factory Note.fromMap(Map<String, Object?> map) => Note(
    id: map['id']! as int,
    title: map['title']! as String,
    body: map['body']! as String,
    pinned: map['pinned'] == 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['updated_at']! as int,
      isUtc: true,
    ),
  );

  /// What the list shows when the title is empty.
  String get displayTitle => title.trim().isEmpty ? 'Untitled' : title.trim();
}
// #enddocregion note
