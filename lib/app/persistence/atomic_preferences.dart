import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small injectable storage boundary for deterministic interrupted-write tests.
abstract interface class PreferenceStorage {
  Object? read(String key);
  Future<bool> write(String key, String value);
  Future<bool> remove(String key);
}

class SharedPreferenceStorage implements PreferenceStorage {
  SharedPreferenceStorage(this.prefs);
  final SharedPreferences prefs;
  @override
  Object? read(String key) => prefs.get(key);
  @override
  Future<bool> write(String key, String value) => prefs.setString(key, value);
  @override
  Future<bool> remove(String key) => prefs.remove(key);
}

String snapshotChecksum(String text) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(text)) {
    final mixed = hash ^ byte;
    final low = (mixed & 0xffff) * 0x0193;
    final high = ((mixed >> 16) * 0x0193 + (mixed & 0xffff) * 0x0100) & 0xffff;
    hash = (low + (high << 16)) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

class StoredSnapshot {
  const StoredSnapshot(
    this.slot,
    this.generation,
    this.payload,
    this.committed,
  );
  final String slot;
  final int generation;
  final String payload;
  final bool committed;
}

/// Writes an entire inactive slot, verifies it, THEN switches the head pointer.
/// A torn slot/head can never combine fields from different game states.
class AtomicPreferences {
  AtomicPreferences(this.storage, this.prefix);
  final PreferenceStorage storage;
  final String prefix;
  String _active = 'b';
  bool _initialized = false;
  int _generation = 0;
  Future<void> _tail = Future.value();
  bool get hasData =>
      ['a', 'b', 'head'].any((s) => storage.read('$prefix.$s') != null);

  List<StoredSnapshot> candidates() {
    final head = storage.read('$prefix.head');
    final out = <StoredSnapshot>[];
    for (final slot in ['a', 'b']) {
      try {
        final raw = storage.read('$prefix.$slot');
        if (raw is! String) continue;
        final data = jsonDecode(raw);
        if (data is! Map ||
            data['envelopeVersion'] != 1 ||
            data['generation'] is! int ||
            data['generation'] < 1 ||
            data['payload'] is! String) {
          continue;
        }
        final payload = data['payload'] as String;
        if (data['checksum'] != snapshotChecksum(payload)) continue;
        final generation = data['generation'] as int;
        out.add(
          StoredSnapshot(
            slot,
            generation,
            payload,
            head == '$slot:$generation',
          ),
        );
      } catch (_) {
        /* A damaged slot does not invalidate the other slot. */
      }
    }
    out.sort(
      (a, b) => a.committed != b.committed
          ? (a.committed ? -1 : 1)
          : b.generation.compareTo(a.generation),
    );
    if (out.isNotEmpty) select(out.first);
    return out;
  }

  void select(StoredSnapshot snapshot) {
    _initialized = true;
    _active = snapshot.slot;
    _generation = snapshot.generation;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final future = _tail.then((_) => action());
    _tail = future.catchError((Object _) {});
    return future;
  }

  Future<void> commit(String payload) => _enqueue(() async {
    if (!_initialized) candidates();
    final slot = _active == 'a' ? 'b' : 'a';
    final generation = _generation + 1;
    final envelope = jsonEncode({
      'envelopeVersion': 1,
      'generation': generation,
      'payload': payload,
      'checksum': snapshotChecksum(payload),
    });
    if (!await storage.write('$prefix.$slot', envelope)) {
      throw StateError('Snapshot write failed');
    }
    if (storage.read('$prefix.$slot') != envelope) {
      throw StateError('Snapshot verification failed');
    }
    if (!await storage.write('$prefix.head', '$slot:$generation')) {
      throw StateError('Snapshot commit failed');
    }
    _initialized = true;
    _active = slot;
    _generation = generation;
  });
  Future<void> clear() => _enqueue(() async {
    // Removing the head first is safe: both complete slots remain recoverable
    // until a confirmed New Game explicitly removes them too.
    for (final slot in ['head', 'a', 'b']) {
      if (!await storage.remove('$prefix.$slot')) {
        throw StateError('Could not clear snapshot');
      }
    }
    _initialized = false;
    _active = 'b';
    _generation = 0;
  });
}
