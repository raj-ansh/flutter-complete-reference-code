// Writes the game's three sound effects into assets/sounds/.
// Run from the project folder:  dart run tool/make_sounds.dart
import 'dart:io';

import 'package:skyline_courier/audio/synth.dart';

void main() {
  final dir = Directory('assets/sounds')..createSync(recursive: true);
  final files = {
    'flap.wav': wavBytes(flapSound()),
    'pickup.wav': wavBytes(pickupSound()),
    'crash.wav': wavBytes(crashSound()),
  };
  files.forEach((name, bytes) {
    File('${dir.path}/$name').writeAsBytesSync(bytes);
    stdout.writeln('wrote ${dir.path}/$name (${bytes.length} bytes)');
  });
}
