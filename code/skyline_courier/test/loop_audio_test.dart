import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyline_courier/audio/synth.dart';
import 'package:skyline_courier/game/fixed_stepper.dart';
import 'package:skyline_courier/game/world.dart';

import 'support/capture.dart';

void main() {
  group('FixedStepper', () {
    test('any frame rate gets the same number of steps per second of real time', () {
      final rows = StringBuffer('10 seconds of real time, frames at different rates\n'
          'frames per second   frames   simulation steps   steps per second\n');
      for (final fps in [24, 30, 60, 90, 120, 144]) {
        final stepper = FixedStepper();
        var steps = 0;
        final frames = fps * 10;
        for (var i = 0; i < frames; i++) {
          steps += stepper.advance(1 / fps);
        }
        rows.writeln('${fps.toString().padRight(20)}${frames.toString().padRight(9)}${steps.toString().padRight(19)}${(steps / 10).toStringAsFixed(1)}');
        expect(steps, closeTo(600, 2), reason: '$fps fps'); // rounding at the very end only
      }
      writeCaptured('sk_stepper_rates.txt', rows.toString());
    });

    test('contrast: "one step per frame" runs the game faster on a faster screen', () {
      final rows = StringBuffer('how far the city scrolls in 10 real seconds\n'
          'frames per second   one step per frame   fixed time step\n');
      for (final fps in [30, 60, 120]) {
        double scrolled(bool perFrame) {
          final w = World(seed: 1)..flap();
          final stepper = FixedStepper();
          // Measure only the scrolling: hold the courier mid-air and remove
          // towers so that nothing can end the game.
          void tick() {
            w.courierY = 300;
            w.courierVy = 0;
            w.towers.clear();
            w.step(1 / 60);
          }

          for (var i = 0; i < fps * 10; i++) {
            if (perFrame) {
              tick(); // one step per frame, whatever the frame rate
            } else {
              final count = stepper.advance(1 / fps); // ask once per frame
              for (var s = 0; s < count; s++) {
                tick();
              }
            }
          }
          return w.distance;
        }

        final naive = scrolled(true);
        final fixed = scrolled(false);
        rows.writeln('${fps.toString().padRight(20)}${naive.toStringAsFixed(0).padRight(22)}${fixed.toStringAsFixed(0)}');
        expect(fixed, closeTo(1200 + 0, 20), reason: '$fps fps, fixed');
        if (fps != 60) expect((naive - 1200).abs(), greaterThan(300), reason: '$fps fps, naive');
      }
      writeCaptured('sk_stepper_naive.txt', rows.toString());
    });

    test('irregular frames still add up, and a long stall is limited', () {
      final random = Random(5);
      final stepper = FixedStepper();
      var total = 0.0;
      var steps = 0;
      for (var i = 0; i < 2000; i++) {
        final dt = 0.008 + random.nextDouble() * 0.03; // 8 to 38 ms, jittery
        total += dt;
        steps += stepper.advance(dt);
      }
      expect(steps, closeTo(total * 60, 2));

      final stalled = FixedStepper();
      expect(stalled.advance(2.0), 5, reason: 'two seconds of stall is cut to five steps');
      expect(stalled.advance(1 / 60), 1, reason: 'and the excess is not "owed" afterwards');
      stalled.advance(0.01);
      stalled.reset();
      expect(stalled.advance(0.005), 0, reason: 'reset forgets saved-up time');
    });
  });

  group('synthesized sound effects', () {
    test('the WAV header says what is in the file', () {
      final bytes = wavBytes(flapSound());
      final data = ByteData.sublistView(bytes);
      String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
      expect([tag(0), tag(8), tag(12), tag(36)], ['RIFF', 'WAVE', 'fmt ', 'data']);
      expect(data.getUint16(20, Endian.little), 1); // PCM
      expect(data.getUint16(22, Endian.little), 1); // mono
      expect(data.getUint32(24, Endian.little), sampleRate);
      expect(data.getUint16(34, Endian.little), 16);
      expect(data.getUint32(40, Endian.little), bytes.length - 44);
      expect(data.getUint32(4, Endian.little), bytes.length - 8);
    });

    test('lengths, loudness and a clean end', () {
      final rows = StringBuffer('effect    seconds   samples   peak (0 to 1)   last sample\n');
      for (final (name, samples) in [
        ('flap', flapSound()),
        ('pickup', pickupSound()),
        ('crash', crashSound()),
      ]) {
        final peak = samples.map((s) => s.abs()).reduce(max);
        rows.writeln('${name.padRight(10)}${(samples.length / sampleRate).toStringAsFixed(2).padRight(10)}${samples.length.toString().padRight(10)}${peak.toStringAsFixed(2).padRight(16)}${samples.last.toStringAsFixed(4)}');
        expect(peak, inInclusiveRange(0.2, 1.0), reason: '$name is audible and does not clip');
        expect(samples.last.abs(), lessThan(0.02), reason: '$name fades out: no click at the end');
        expect(samples.length / sampleRate, lessThan(0.5), reason: '$name is short');
      }
      writeCaptured('sk_sounds.txt', rows.toString());
    });

    test('clipping is clamped, not wrapped around', () {
      final bytes = wavBytes([2.0, -2.0, 0.0]);
      final data = ByteData.sublistView(bytes);
      expect(data.getInt16(44, Endian.little), 32767);
      expect(data.getInt16(46, Endian.little), -32767);
      expect(data.getInt16(48, Endian.little), 0);
    });

    test('the .wav files in assets are exactly what the generator makes', () {
      for (final (name, samples) in [
        ('flap', flapSound()),
        ('pickup', pickupSound()),
        ('crash', crashSound()),
      ]) {
        final onDisk = File('assets/sounds/$name.wav').readAsBytesSync();
        expect(onDisk, orderedEquals(wavBytes(samples)), reason: '$name.wav is out of date: run dart run tool/make_sounds.dart');
      }
    });
  });
}
