import 'dart:io';

import 'package:flutter/material.dart';

import 'contact.dart';

// #docregion avatar
/// The contact's photo, or their initials when there is none.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.radius = 20});

  final Contact contact;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = contact.photoPath;
    final scale = MediaQuery.devicePixelRatioOf(context);
    return CircleAvatar(
      radius: radius,
      // Decode only as many pixels as the avatar shows (Chapter 16).
      foregroundImage: path == null
          ? null
          : ResizeImage(
              FileImage(File(path)),
              width: (radius * 2 * scale).round(),
            ),
      // Shown while the photo loads, and if the file has gone missing.
      onForegroundImageError: path == null ? null : (_, _) {},
      child: Text(contact.initials),
    );
  }
}
// #enddocregion avatar
