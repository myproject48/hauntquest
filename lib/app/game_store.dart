import 'package:shared_preferences/shared_preferences.dart';

import '../content/game_content.dart';
import '../domain/models/game_state.dart';
import 'persistence/atomic_preferences.dart';
import 'persistence/save_codec.dart';

abstract interface class GameStore {
  Future<GameState?> load();
  Future<void> save(GameState state);
  Future<void> clear();
}

enum SaveRecovery {
  missing,
  restored,
  migrated,
  recoveredBackup,
  corrupt,
  unsupported,
}

abstract interface class SaveDiagnostics {
  SaveRecovery get recovery;
  bool get hasStoredProgress;
}

/// Alternating checksummed snapshots, previous valid backup and a commit head.
/// SharedPreferences is local storage, not a power-loss guarantee; complete
/// snapshots are validated before commit and again before restoration.
class PrefsGameStore implements GameStore, SaveDiagnostics {
  PrefsGameStore(SharedPreferences prefs, {GameContent? content})
    : this.withStorage(SharedPreferenceStorage(prefs), content: content);
  PrefsGameStore.withStorage(PreferenceStorage storage, {GameContent? content})
    : _storage = storage,
      _journal = AtomicPreferences(storage, prefix),
      _codec = SaveCodec(content);
  static const prefix = 'hauntquest.save.v2';
  static const legacyKey = 'hauntquest.save.active_journey.v1';
  final PreferenceStorage _storage;
  final AtomicPreferences _journal;
  final SaveCodec _codec;
  SaveRecovery _recovery = SaveRecovery.missing;
  bool _futureVersion = false;
  bool _loaded = false;
  Future<void> _writes = Future.value();
  Future<void> _serialize(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.catchError((Object _) {});
    return result;
  }

  @override
  SaveRecovery get recovery => _recovery;
  @override
  bool get hasStoredProgress =>
      _journal.hasData || _storage.read(legacyKey) != null;
  static Future<PrefsGameStore> open({GameContent? content}) async =>
      PrefsGameStore(await SharedPreferences.getInstance(), content: content);

  @override
  Future<GameState?> load() async {
    _loaded = true;
    final candidates = _journal.candidates();
    for (var i = 0; i < candidates.length; i++) {
      try {
        final state = _codec.decode(candidates[i].payload);
        _journal.select(candidates[i]);
        _recovery = i == 0 && candidates[i].committed
            ? SaveRecovery.restored
            : SaveRecovery.recoveredBackup;
        return state;
      } on UnsupportedSaveVersion {
        _futureVersion = true;
        _recovery = SaveRecovery.unsupported;
        return null;
      } catch (_) {
        /* Try the previous complete snapshot. */
      }
    }
    final legacy = _storage.read(legacyKey);
    if (legacy is String) {
      try {
        final state = _codec.decode(legacy);
        _recovery = candidates.isEmpty && !_journal.hasData
            ? SaveRecovery.migrated
            : SaveRecovery.recoveredBackup;
        try {
          await _journal.commit(_codec.encode(state));
        } catch (_) {
          /* Legacy copy remains intact. */
        }
        return state;
      } on UnsupportedSaveVersion {
        _futureVersion = true;
        _recovery = SaveRecovery.unsupported;
        return null;
      } catch (_) {
        /* Preserve invalid data until a confirmed New Game. */
      }
    }
    _recovery = hasStoredProgress ? SaveRecovery.corrupt : SaveRecovery.missing;
    return null;
  }

  @override
  Future<void> save(GameState state) => _serialize(() async {
    if (!_loaded) await load();
    if (_futureVersion) throw const UnsupportedSaveVersion(-1);
    await _journal.commit(_codec.encode(state));
  });
  @override
  Future<void> clear() => _serialize(() async {
    await _journal.clear();
    if (!await _storage.remove(legacyKey)) {
      throw StateError('Could not clear legacy save');
    }
    _futureVersion = false;
    _loaded = true;
    _recovery = SaveRecovery.missing;
  });
}

class MemoryGameStore implements GameStore {
  MemoryGameStore([this.savedState]);
  GameState? savedState;
  int saveCount = 0;
  int clearCount = 0;
  @override
  Future<GameState?> load() async => savedState;
  @override
  Future<void> save(GameState state) async {
    savedState = state;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    savedState = null;
    clearCount++;
  }
}
