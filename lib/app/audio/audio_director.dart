import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/audio/sound_cue.dart';
import '../game_controller.dart';
import '../settings_controller.dart';
import 'audio_backend.dart';

/// Presentation-only audio consumes engine events; it cannot change gameplay.
class AudioDirector extends ChangeNotifier {
  AudioDirector({
    required this.game,
    required this.settings,
    required this.backend,
  }) {
    game.pulses.addListener(_pulse);
    game.addListener(_sync);
    settings.addListener(_sync);
    _known = game.engine.narrative.journal(game.state).map((e) => e.id).toSet();
  }
  final GameController game;
  final SettingsController settings;
  final AudioBackend backend;
  bool _foreground = true;
  bool _started = false;
  bool _disposed = false;
  bool _audible = false;
  String? _ambient;
  double _ambientVolume = -1;
  double _effectsVolume = -1;
  Set<String> _known = {};
  Object? _lastError;
  Object? get lastError => _lastError;
  Future<void> _queue = Future.value();
  Future<void> flush() => _queue;
  bool get foreground => _foreground;
  double get ambientGain => settings.settings.muted
      ? 0
      : settings.settings.masterVolume * settings.settings.ambientVolume;
  double get effectGain => settings.settings.muted
      ? 0
      : settings.settings.masterVolume * settings.settings.effectsVolume;

  void start() {
    _started = true;
    _sync();
  }

  void _run(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await action().timeout(const Duration(seconds: 3));
        // A later success means sound works again: drop the stale warning
        // so Settings does not report a failure that no longer applies.
        if (_lastError != null && !_disposed) {
          _lastError = null;
          notifyListeners();
        }
      } catch (error) {
        debugPrint('HauntQuest audio: $error (gameplay continues silently)');
        if (!_disposed) {
          _lastError = error;
          _ambient = null;
          notifyListeners();
        }
      }
    });
  }

  void _sync() {
    if (_disposed || !_started) return;
    final active =
        _foreground &&
        !settings.settings.muted &&
        settings.settings.masterVolume > 0;
    if (active != _audible) {
      _audible = active;
      // SetActive updates its gate synchronously before waiting on native I/O.
      unawaited(
        backend.setActive(active).catchError((Object error) {
          debugPrint('HauntQuest audio: setActive($active) failed: $error');
        }),
      );
      if (!active) _ambient = null;
    }
    if (!active) return;
    final ambient = game.endingId == null
        ? ambienceAsset(game.currentRoomId)
        : null;
    final av = ambientGain, ev = effectGain;
    if (av != _ambientVolume || ev != _effectsVolume) {
      _ambientVolume = av;
      _effectsVolume = ev;
      _run(() => backend.setVolumes(av, ev));
    }
    if (ambient != _ambient || av != _appliedAmbientGain) {
      _ambient = ambient;
      _appliedAmbientGain = av;
      _run(() async {
        if (_foreground && _audible) await backend.ambient(ambient, av);
      });
    }
  }

  double _appliedAmbientGain = -1;
  void _pulse() {
    if (!_started) start();
    _sync();
    final pulse = game.pulses.value;
    if (pulse == null) return;
    final cues = soundsFor(pulse.events);
    final known = game.engine.narrative
        .journal(game.state)
        .map((e) => e.id)
        .toSet();
    if (known.difference(_known).isNotEmpty &&
        !cues.any(
          (c) => [
            SoundCue.endingRelease,
            SoundCue.endingGuardian,
            SoundCue.endingSeal,
          ].contains(c),
        )) {
      cues.add(SoundCue.discovery);
    }
    _known = known;
    for (final cue in cues.take(3)) {
      play(cue);
    }
  }

  void play(SoundCue cue) {
    if (!_foreground || !_audible || _disposed || effectGain == 0) return;
    final gain = effectGain;
    _run(() async {
      if (_foreground && _audible && effectGain > 0) {
        await backend.effect(cue, gain);
      }
    });
  }

  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    _sync();
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    game.pulses.removeListener(_pulse);
    game.removeListener(_sync);
    settings.removeListener(_sync);
    try {
      await backend.setActive(false);
    } catch (error) {
      debugPrint('HauntQuest audio: could not stop on close: $error');
    }
    await _queue;
    try {
      await backend.dispose();
    } catch (error) {
      debugPrint('HauntQuest audio: could not release players: $error');
    }
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
