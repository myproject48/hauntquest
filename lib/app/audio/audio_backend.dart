import '../../domain/audio/sound_cue.dart';

abstract interface class AudioBackend {
  Future<void> setActive(bool active);
  Future<void> setVolumes(double ambient, double effects);
  Future<void> ambient(String? asset, double volume);
  Future<void> effect(SoundCue cue, double volume);
  Future<void> dispose();
}

/// Tests and non-audio hosts inject this; production injects LocalAudioBackend.
class SilentAudioBackend implements AudioBackend {
  @override
  Future<void> setActive(bool active) async {}
  @override
  Future<void> setVolumes(double ambient, double effects) async {}
  @override
  Future<void> ambient(String? asset, double volume) async {}
  @override
  Future<void> effect(SoundCue cue, double volume) async {}
  @override
  Future<void> dispose() async {}
}
