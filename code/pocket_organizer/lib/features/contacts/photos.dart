import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/clock.dart';
import '../../core/result.dart';

// #docregion photoports
enum PhotoOrigin { camera, gallery }

/// Asks the user for a picture. Returns the path of a temporary file, null if
/// the user cancelled, or an [Err] when the system refused or failed.
abstract interface class PhotoPicker {
  Future<Result<String?>> pick(PhotoOrigin origin);
}

/// Keeps a picked picture inside the app's own storage and removes it later.
abstract interface class PhotoStorage {
  Future<String> keep(String pickedPath);
  Future<void> remove(String path);
}
// #enddocregion photoports

// #docregion imagepicker
/// The real picker, built on the image_picker plugin. Its camera and gallery
/// screens belong to the operating system; this class only asks for a result.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Result<String?>> pick(PhotoOrigin origin) async {
    try {
      final file = await _picker.pickImage(
        source: origin == PhotoOrigin.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // A contact avatar never needs a 12-megapixel original.
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      return Ok(file?.path); // null: the user backed out
    } on PlatformException {
      // For example: permission denied, or no camera on this device.
      return Err(
        origin == PhotoOrigin.camera
            ? 'The camera is not available. Check the app\'s camera permission.'
            : 'Could not open your photos. Check the app\'s photo permission.',
      );
    }
  }
}
// #enddocregion imagepicker

// #docregion filestorage
/// Copies pictures into [directory] under a name the app chooses.
class FilePhotoStorage implements PhotoStorage {
  FilePhotoStorage(this.directory, this._clock);

  final Directory directory;
  final Clock _clock;
  int _counter = 0;

  @override
  Future<String> keep(String pickedPath) async {
    await directory.create(recursive: true);
    // The picker's file is a temporary one and may disappear. Keep a copy.
    final name =
        'contact_${_clock.now().millisecondsSinceEpoch}_${_counter++}'
        '${p.extension(pickedPath)}';
    final target = p.join(directory.path, name);
    await File(pickedPath).copy(target);
    return target;
  }

  @override
  Future<void> remove(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
// #enddocregion filestorage
