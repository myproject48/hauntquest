import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hauntquest/app/audio/audio_backend.dart';
import 'package:hauntquest/app/audio/audio_director.dart';
import 'package:hauntquest/app/game_controller.dart';
import 'package:hauntquest/app/settings_controller.dart';
import 'package:hauntquest/domain/audio/sound_cue.dart';
import 'package:hauntquest/domain/engine/game_events.dart';
import 'package:hauntquest/domain/puzzles/puzzle_evaluator.dart';

import '../content/content_fixture.dart';
import '../ui/ui_harness.dart' show MemorySettingsStore;

class RecordingAudioBackend implements AudioBackend {
  final List<SoundCue> cues = [];
  final List<(String?, double)> ambience = [];
  final List<(double, double)> volumes = [];
  final List<bool> active = [];
  bool disposed = false;
  bool fail = false;
  void _check() {
    if (fail) throw StateError('audio device unavailable');
  }

  @override
  Future<void> setActive(bool value) async {
    active.add(value);
  }

  @override
  Future<void> setVolumes(double ambient, double effects) async {
    _check();
    volumes.add((ambient, effects));
  }

  @override
  Future<void> ambient(String? asset, double volume) async {
    _check();
    ambience.add((asset, volume));
  }

  @override
  Future<void> effect(SoundCue cue, double volume) async {
    _check();
    cues.add(cue);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  final content = contentFrom(freshRaw());
  test(
    'all required game events map to bounded and meaningful original sounds',
    () {
      expect(soundsFor([const ItemAcquired('key')]), contains(SoundCue.pickup));
      expect(soundsFor([const ExitOpened('door')]), contains(SoundCue.unlock));
      expect(soundsFor([const PuzzleAttempted('p', 1)]), [SoundCue.failure]);
      expect(
        soundsFor([const PuzzleAttempted('p', 1), const PuzzleSolved('p')]),
        [SoundCue.success],
      );
      expect(soundsFor([const RoomEntered('r', firstVisit: true)]), [
        SoundCue.footstep,
        SoundCue.chapter,
      ]);
      expect(soundsFor([const RoomEntered('r', firstVisit: false)]), [
        SoundCue.footstep,
      ]);
      expect(soundsFor([const HotspotExamined('h', firstTime: true)]), [
        SoundCue.interact,
      ]);
      expect(soundsFor([const EndingReached('seal_echo')]), [
        SoundCue.endingSeal,
      ]);
      expect(soundsFor([const EndingReached('release_echo')]), [
        SoundCue.endingRelease,
      ]);
      expect(soundsFor([const EndingReached('echo_guardian')]), [
        SoundCue.endingGuardian,
      ]);
    },
  );
  test(
    'audio settings persist atomically and survive a new controller',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await PrefsSettingsStore.open();
      final controller = SettingsController(store);
      await controller.update(
        const AppSettings(
          masterVolume: .3,
          ambientVolume: .2,
          effectsVolume: .9,
          muted: true,
          reducedMotion: true,
        ),
      );
      final restored = await SettingsController.load(
        await PrefsSettingsStore.open(),
      );
      expect(restored.settings, controller.settings);
      controller.dispose();
      restored.dispose();
    },
  );
  test(
    'invalid and old settings recover with safe bounded volume defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings.v1.textScale': 'bad',
        'settings.v1.reducedMotion': true,
        'settings.v1.highContrast': 23,
      });
      final settings = await (await PrefsSettingsStore.open()).load();
      expect(settings.textScale, 1);
      expect(settings.reducedMotion, isTrue);
      expect(settings.highContrast, isFalse);
      final parsed = AppSettings.fromJson({
        'masterVolume': -99,
        'ambientVolume': 500,
        'effectsVolume': double.nan,
        'muted': 'true',
      });
      expect(parsed.masterVolume, 0);
      expect(parsed.ambientVolume, 1);
      expect(parsed.effectsVolume, const AppSettings().effectsVolume);
      expect(parsed.muted, isFalse);
    },
  );
  test('settings corruption recovers the previous complete mix', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsSettingsStore(prefs);
    await store.save(const AppSettings(masterVolume: .2));
    await store.save(const AppSettings(masterVolume: .8));
    final slot = prefs.getString('settings.v2.head')!.split(':').first;
    await prefs.setString('settings.v2.$slot', 'corrupt');
    expect((await PrefsSettingsStore(prefs).load()).masterVolume, .2);
  });
  test('mix changes apply without changing game state; mute and background suppress all effects', () async {
    final game = GameController(content);
    final settings = SettingsController(MemorySettingsStore());
    final backend = RecordingAudioBackend();
    final audio = AudioDirector(
      game: game,
      settings: settings,
      backend: backend,
    )..start();
    await audio.flush();
    expect(backend.ambience.last.$1, ambienceAsset(game.currentRoomId));
    expect(audio.ambientGain, closeTo(.245, .0001));
    game.examine('h_portrait');
    await audio.flush();
    expect(backend.cues, contains(SoundCue.pickup));
    final state = game.state;
    await settings.update(
      settings.settings.copyWith(
        masterVolume: .5,
        ambientVolume: .2,
        effectsVolume: .4,
      ),
    );
    await audio.flush();
    expect(backend.volumes.last, (.1, .2));
    expect(game.state, state);
    await settings.update(settings.settings.copyWith(muted: true));
    final n = backend.cues.length;
    audio.play(SoundCue.success);
    await audio.flush();
    expect(backend.cues.length, n);
    expect(backend.active.last, isFalse);
    await settings.update(settings.settings.copyWith(muted: false));
    await audio.flush();
    audio.setForeground(false);
    audio.play(SoundCue.unlock);
    await audio.flush();
    expect(backend.cues.length, n);
    expect(backend.active.last, isFalse);
    audio.setForeground(true);
    await audio.flush();
    expect(backend.active.last, isTrue);
    expect(game.state, state);
    await audio.close();
    audio.dispose();
    game.dispose();
    settings.dispose();
    expect(backend.disposed, isTrue);
  });
  test(
    'audio failure cannot prevent a puzzle, discovery or inventory transition',
    () async {
      final game = GameController(content);
      final settings = SettingsController(MemorySettingsStore());
      final backend = RecordingAudioBackend()..fail = true;
      final audio = AudioDirector(
        game: game,
        settings: settings,
        backend: backend,
      )..start();
      game.examine('h_portrait');
      game.submitPuzzle(
        'p1_candle_moons',
        const SequenceInput(['crescent', 'half', 'full', 'waning']),
      );
      await audio.flush();
      expect(game.hasItem('brass_winding_key'), isTrue);
      expect(game.puzzleSolved('p1_candle_moons'), isTrue);
      expect(audio.lastError, isNotNull);
      await audio.close();
      audio.dispose();
      game.dispose();
      settings.dispose();
    },
  );
  test('a transient audio failure clears once sound works again', () async {
    final game = GameController(content);
    final settings = SettingsController(MemorySettingsStore());
    final backend = RecordingAudioBackend()..fail = true;
    final audio = AudioDirector(
      game: game,
      settings: settings,
      backend: backend,
    )..start();
    audio.play(SoundCue.pickup);
    await audio.flush();
    expect(audio.lastError, isNotNull, reason: 'failure is reported');
    backend.fail = false;
    audio.play(SoundCue.pickup);
    await audio.flush();
    expect(audio.lastError, isNull, reason: 'recovery clears the warning');
    await audio.close();
    audio.dispose();
    game.dispose();
    settings.dispose();
  });
  test('discoveries emit a chime once and repeated examination cannot duplicate rewards', () async {
    final game = GameController(content);
    final settings = SettingsController(MemorySettingsStore());
    final backend = RecordingAudioBackend();
    final audio = AudioDirector(
      game: game,
      settings: settings,
      backend: backend,
    )..start();
    game.submitPuzzle(
      'p1_candle_moons',
      const SequenceInput(['crescent', 'half', 'full', 'waning']),
    );
    game.examine('h_portrait');
    game.useItem('brass_winding_key', 'h_tallow');
    game.move('hall_to_library');
    game.examine('l_desk');
    await audio.flush();
    expect(backend.cues, contains(SoundCue.discovery));
    final discoveries = backend.cues
        .where((c) => c == SoundCue.discovery)
        .length;
    game.examine('l_desk');
    await audio.flush();
    expect(
      backend.cues.where((c) => c == SoundCue.discovery).length,
      discoveries,
    );
    expect(
      game.inventory.where((id) => id == 'ottoline_journal'),
      hasLength(1),
    );
    await audio.close();
    audio.dispose();
    game.dispose();
    settings.dispose();
  });
  test('all bundled sounds are bounded original PCM with valid headers and no clipped samples', () {
    final paths = {
      ...SoundCue.values.map(soundAsset),
      ...content.rooms.map((r) => ambienceAsset(r.id)),
    };
    expect(paths, hasLength(20));
    for (final asset in paths) {
      final bytes = File('assets/$asset').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(20, Endian.little), 1);
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), 16000);
      expect(data.getUint16(34, Endian.little), 16);
      expect(data.getUint32(40, Endian.little) + 44, bytes.length);
      expect(bytes.length, lessThanOrEqualTo(256044));
      for (var i = 44; i < bytes.length; i += 2) {
        expect(data.getInt16(i, Endian.little).abs(), lessThan(32767));
      }
    }
  });
}
