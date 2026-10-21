import 'dart:math';
import 'dart:typed_data';

// The game's sound effects are made by this code, not recorded or downloaded,
// so there is nothing to license: the author of the code owns them. The same
// functions are used by tool/make_sounds.dart (which writes the .wav files into
// the app's assets) and by the tests.

const sampleRate = 22050;

// #docregion wav
/// Wraps 16-bit mono samples in a WAV file: a 44-byte header, then the samples.
Uint8List wavBytes(List<double> samples) {
  final dataBytes = samples.length * 2;
  final out = ByteData(44 + dataBytes);
  void text(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // size of this block
  out.setUint16(20, 1, Endian.little); // 1 = plain PCM
  out.setUint16(22, 1, Endian.little); // one channel
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * 2, Endian.little); // bytes per second
  out.setUint16(32, 2, Endian.little); // bytes per sample frame
  out.setUint16(34, 16, Endian.little); // bits per sample
  text(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    out.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
  }
  return out.buffer.asUint8List();
}
// #enddocregion wav

// #docregion sounds
/// A short rising chirp, like a puff of air: 440 Hz sliding up to 700 Hz.
List<double> flapSound() {
  const seconds = 0.12;
  final count = (sampleRate * seconds).round();
  var phase = 0.0;
  return List.generate(count, (i) {
    final t = i / count; // 0 to 1 through the sound
    final frequency = 440 + 260 * t;
    phase += 2 * pi * frequency / sampleRate;
    final fade = pow(1 - t, 2).toDouble(); // dies away smoothly
    return sin(phase) * 0.45 * fade;
  });
}

/// Two quick notes going up (a major third apart): a pleasant "got it".
List<double> pickupSound() {
  const seconds = 0.22;
  final count = (sampleRate * seconds).round();
  return List.generate(count, (i) {
    final t = i / sampleRate;
    final frequency = t < 0.09 ? 660.0 : 830.0;
    final local = t < 0.09 ? t : t - 0.09;
    final length = t < 0.09 ? 0.09 : seconds - 0.09;
    final fade = 1 - local / length;
    return sin(2 * pi * frequency * t) * 0.4 * fade;
  });
}

/// A burst of noise that fades, over a low falling tone. [seed] makes the noise
/// the same every time, so the file the tool writes never changes.
List<double> crashSound({int seed = 7}) {
  const seconds = 0.4;
  final random = Random(seed);
  final count = (sampleRate * seconds).round();
  var phase = 0.0;
  return List.generate(count, (i) {
    final t = i / count;
    phase += 2 * pi * (160 - 100 * t) / sampleRate;
    final noise = random.nextDouble() * 2 - 1;
    final fade = pow(1 - t, 1.5).toDouble();
    return (noise * 0.35 + sin(phase) * 0.35) * fade;
  });
}
// #enddocregion sounds
