import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../domain/audio/sound_cue.dart';
import 'audio_backend.dart';

/// Fixed native player budget: one ambient loop and three short-effect voices.
/// All assets are local original PCM. No per-frame position polling or DSP.
class LocalAudioBackend implements AudioBackend {
  AudioPlayer? _ambience;
  final List<AudioPlayer> _voices = [];
  Future<void>? _ready;
  bool _active = true;
  bool _disposed = false;
  int _generation = 0;
  int _voice = 0;
  String? _ambientAsset;
  Future<void> _init() => _ready ??= _create();
  Future<void> _create() async {
    final context = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        stayAwake: false,
        isSpeakerphoneOn: false,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );
    // Short effects play under the ambient loop's focus. Requesting focus per
    // effect made the app's own players duck each other on Android (seen in
    // logcat on an API 37 emulator) and slowed every cue.
    final effectContext = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
        stayAwake: false,
        isSpeakerphoneOn: false,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );
    final ambient = AudioPlayer()..positionUpdater = null;
    _ambience = ambient;
    await ambient.setAudioContext(context);
    await ambient.setReleaseMode(ReleaseMode.loop);
    for (var i = 0; i < 3; i++) {
      if (_disposed) break;
      final p = AudioPlayer()..positionUpdater = null;
      _voices.add(p);
      await p.setAudioContext(effectContext);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await p.setPlayerMode(PlayerMode.lowLatency);
      }
      await p.setReleaseMode(ReleaseMode.stop);
    }
  }

  @override
  Future<void> setActive(bool active) async {
    if (_disposed) return;
    _active = active;
    if (!active) {
      _generation++;
      _ambientAsset = null;
      await Future.wait([
        if (_ambience != null) _ambience!.stop(),
        for (final p in _voices) p.stop(),
      ]);
    }
  }

  @override
  Future<void> setVolumes(double ambient, double effects) async {
    if (_disposed) return;
    await Future.wait([
      if (_ambience != null) _ambience!.setVolume(ambient),
      for (final p in _voices) p.setVolume(effects),
    ]);
  }

  @override
  Future<void> ambient(String? asset, double volume) async {
    if (_disposed) return;
    if (asset == null || volume == 0) {
      _ambientAsset = null;
      await _ambience?.stop();
      return;
    }
    final generation = _generation;
    await _init();
    if (!_active || _disposed || generation != _generation) return;
    final p = _ambience!;
    await p.setVolume(volume);
    if (_ambientAsset == asset) return;
    await p.stop();
    await p.setSource(AssetSource(asset));
    if (!_active || _disposed || generation != _generation) return;
    await p.resume();
    _ambientAsset = asset;
  }

  @override
  Future<void> effect(SoundCue cue, double volume) async {
    if (_disposed || !_active || volume == 0) return;
    final generation = _generation;
    await _init();
    if (_disposed || !_active || generation != _generation || _voices.isEmpty) {
      return;
    }
    final p = _voices[_voice++ % _voices.length];
    await p.stop();
    await p.setVolume(volume);
    await p.setSource(AssetSource(soundAsset(cue)));
    if (_disposed || !_active || generation != _generation) return;
    await p.resume();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _generation++;
    try {
      await _ready;
    } catch (error) {
      // Still release the players that were created before the failure.
      debugPrint('HauntQuest audio: player setup had failed: $error');
    }
    await Future.wait([
      if (_ambience != null) _ambience!.dispose(),
      for (final p in _voices) p.dispose(),
    ]);
    _voices.clear();
    _ambience = null;
  }
}
