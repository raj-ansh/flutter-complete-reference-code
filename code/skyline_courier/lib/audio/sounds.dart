import 'package:audioplayers/audioplayers.dart';

// #docregion sounds
enum SoundEffect { flap, pickup, crash }

/// What the game needs from audio. The game depends on this interface, so the
/// tests can record which effects were requested without making a sound.
abstract interface class GameSounds {
  Future<void> play(SoundEffect effect);
  Future<void> dispose();
}

/// Plays nothing. Used when sound is switched off, and in tests.
class SilentSounds implements GameSounds {
  const SilentSounds();
  @override
  Future<void> play(SoundEffect effect) async {}
  @override
  Future<void> dispose() async {}
}

/// The real thing, using the audioplayers plugin: one player per effect, so
/// that a flap sound never cuts off a pickup sound.
class AudioplayersSounds implements GameSounds {
  AudioplayersSounds() {
    for (final effect in SoundEffect.values) {
      _players[effect] = AudioPlayer()
        ..setPlayerMode(PlayerMode.lowLatency) // short effects, minimal delay
        ..setReleaseMode(ReleaseMode.stop);
    }
  }

  final _players = <SoundEffect, AudioPlayer>{};

  @override
  Future<void> play(SoundEffect effect) async {
    try {
      // Paths are relative to the assets/ folder declared in pubspec.yaml.
      await _players[effect]!.play(AssetSource('sounds/${effect.name}.wav'));
    } on Object {
      // A device without audio, or a decoding problem, must never stop the
      // game: sound is a nicety.
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
  }
}
// #enddocregion sounds
