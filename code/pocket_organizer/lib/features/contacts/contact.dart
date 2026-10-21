import 'package:flutter/foundation.dart';

// #docregion contact
@immutable
class Contact {
  const Contact({
    this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.photoPath,
  });

  final int? id;
  final String name;
  final String phone;
  final String email;

  /// A file inside the app's own storage, or null for "no photo".
  final String? photoPath;

  /// One or two capital letters for the avatar when there is no photo.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words
        .map((w) => String.fromCharCode(w.runes.first))
        .toList();
    if (letters.isEmpty) return '?';
    final picked = letters.length == 1
        ? letters.first
        : letters.first + letters.last;
    return picked.toUpperCase();
  }

  /// The nullable photo uses the function-wrapper form (Chapter 18).
  Contact copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? Function()? photoPath,
  }) => Contact(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    photoPath: photoPath != null ? photoPath() : this.photoPath,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'photo_path': photoPath,
  };

  factory Contact.fromMap(Map<String, Object?> map) => Contact(
    id: map['id']! as int,
    name: map['name']! as String,
    phone: map['phone']! as String,
    email: map['email']! as String,
    photoPath: map['photo_path'] as String?,
  );
}
// #enddocregion contact
