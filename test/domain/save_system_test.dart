import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/game_controller.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/app/persistence/atomic_preferences.dart';
import 'package:hauntquest/app/persistence/save_codec.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/models/game_state.dart';
import 'package:hauntquest/domain/narrative/narrative_engine.dart';

import '../content/content_fixture.dart';
import 'narrative_fixture.dart';

class TestPreferences implements PreferenceStorage {
  final Map<String, Object?> data = {};
  int writes = 0;
  int? failAt;
  bool tear = false;
  @override
  Object? read(String key) => data[key];
  @override
  Future<bool> write(String key, String value) async {
    writes++;
    if (writes == failAt) {
      if (tear) data[key] = value.substring(0, value.length ~/ 2);
      return false;
    }
    data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    data.remove(key);
    return true;
  }
}

class DelayedGameStore implements GameStore {
  final Completer<void> first = Completer();
  final List<GameState> completed = [];
  int concurrent = 0, maximum = 0;
  int clears = 0;
  @override
  Future<GameState?> load() async => completed.lastOrNull;
  @override
  Future<void> save(GameState s) async {
    concurrent++;
    if (concurrent > maximum) maximum = concurrent;
    if (completed.isEmpty) await first.future;
    completed.add(s);
    concurrent--;
  }

  @override
  Future<void> clear() async {
    clears++;
    completed.clear();
  }
}

void main() {
  final content = contentFrom(freshRaw());
  final engine = GameEngine(content);
  final initial = engine.newGame();
  final found = engine.examine(initial, 'h_portrait').state;
  final codec = SaveCodec(content);
  String envelope(String payload, int generation) => jsonEncode({
    'envelopeVersion': 1,
    'generation': generation,
    'payload': payload,
    'checksum': snapshotChecksum(payload),
  });

  test(
    'snapshot checksum is portable across native and web integer semantics',
    () {
      expect(snapshotChecksum(''), '811c9dc5');
      expect(snapshotChecksum('hello'), '4f9f2cab');
    },
  );
  test('full progress, journal, flags, transcripts, drafts and ending restore through a new store', () async {
    final prefs = TestPreferences();
    final state = engine
        .resolveChoice(
          reachFinalDecision(content),
          'c_echo_fate',
          'ef_guardian',
        )
        .state;
    await PrefsGameStore.withStorage(prefs, content: content).save(state);
    final reloaded = await PrefsGameStore.withStorage(
      prefs,
      content: content,
    ).load();
    expect(reloaded, isNotNull);
    expect(reloaded!.schemaVersion, 2);
    expect(reloaded.currentRoomId, state.currentRoomId);
    expect(reloaded.inventory, state.inventory);
    expect(reloaded.solvedPuzzleIds, state.solvedPuzzleIds);
    expect(reloaded.flags, state.flags);
    expect(reloaded.resolvedChoices, state.resolvedChoices);
    expect(
      reloaded.dialogueRecords.map((k, v) => MapEntry(k, v.toJson())),
      state.dialogueRecords.map((k, v) => MapEntry(k, v.toJson())),
    );
    expect(reloaded.puzzleProgress.keys, state.puzzleProgress.keys);
    expect(reloaded.endingId, 'echo_guardian');
    expect(
      reloaded.journalEntryIds,
      NarrativeEngine(content).journal(state).map((e) => e.id).toSet(),
    );
  });
  test('missing saves return a safe empty result', () async {
    final store = PrefsGameStore.withStorage(
      TestPreferences(),
      content: content,
    );
    expect(await store.load(), isNull);
    expect(store.recovery, SaveRecovery.missing);
  });
  for (final bad in ['{', 'null', '[]', '{}', '{"currentRoomId":77}']) {
    test('invalid legacy save $bad is rejected without deleting it', () async {
      final prefs = TestPreferences()..data[PrefsGameStore.legacyKey] = bad;
      final store = PrefsGameStore.withStorage(prefs, content: content);
      expect(await store.load(), isNull);
      expect(store.recovery, SaveRecovery.corrupt);
      expect(prefs.data[PrefsGameStore.legacyKey], bad);
    });
  }
  test(
    'a truncated active slot recovers the previous complete state',
    () async {
      final prefs = TestPreferences();
      final store = PrefsGameStore.withStorage(prefs, content: content);
      await store.save(initial);
      await store.save(found);
      final active = (prefs.data['${PrefsGameStore.prefix}.head'] as String)
          .split(':')
          .first;
      prefs.data['${PrefsGameStore.prefix}.$active'] = '{"partial":';
      final next = PrefsGameStore.withStorage(prefs, content: content);
      expect((await next.load())!.inventory, initial.inventory);
      expect(next.recovery, SaveRecovery.recoveredBackup);
    },
  );
  test(
    'corrupt commit pointer recovers a whole checksummed snapshot',
    () async {
      final prefs = TestPreferences();
      final store = PrefsGameStore.withStorage(prefs, content: content);
      await store.save(initial);
      await store.save(found);
      prefs.data['${PrefsGameStore.prefix}.head'] = 'torn';
      final loaded = await PrefsGameStore.withStorage(
        prefs,
        content: content,
      ).load();
      expect(loaded!.inventory, found.inventory);
    },
  );
  for (final step in [1, 2]) {
    test(
      'write failure at transaction step $step preserves the committed snapshot',
      () async {
        final prefs = TestPreferences();
        final store = PrefsGameStore.withStorage(prefs, content: content);
        await store.save(initial);
        prefs.failAt = prefs.writes + step;
        prefs.tear = step == 1;
        await expectLater(store.save(found), throwsStateError);
        final loaded = await PrefsGameStore.withStorage(
          prefs,
          content: content,
        ).load();
        expect(loaded!.inventory, initial.inventory);
      },
    );
  }
  test('a well-formed but semantically invalid head falls back without destroying the good backup', () async {
    final prefs = TestPreferences();
    final store = PrefsGameStore.withStorage(prefs, content: content);
    await store.save(initial);
    final invalid = initial.toJson()..['currentRoomId'] = 'missing';
    prefs.data['${PrefsGameStore.prefix}.b'] = envelope(jsonEncode(invalid), 2);
    prefs.data['${PrefsGameStore.prefix}.head'] = 'b:2';
    final recovered = PrefsGameStore.withStorage(prefs, content: content);
    expect((await recovered.load())!.currentRoomId, initial.currentRoomId);
    prefs.failAt = prefs.writes + 1;
    prefs.tear = true;
    await expectLater(recovered.save(found), throwsStateError);
    expect(
      (await PrefsGameStore.withStorage(
        prefs,
        content: content,
      ).load())!.inventory,
      initial.inventory,
    );
  });
  test('v1 saves migrate IDs and fields into a durable v2 snapshot', () async {
    final old = initial.toJson()..['schemaVersion'] = 1;
    old.remove('journalEntryIds');
    old.remove('puzzleProgress');
    old.remove('dialogueRecords');
    final prefs = TestPreferences()
      ..data[PrefsGameStore.legacyKey] = jsonEncode(old);
    final store = PrefsGameStore.withStorage(prefs, content: content);
    final state = await store.load();
    expect(state!.schemaVersion, 2);
    expect(store.recovery, SaveRecovery.migrated);
    expect(state.inventory, initial.inventory);
    expect(prefs.data.containsKey('${PrefsGameStore.prefix}.head'), isTrue);
    expect(
      (await PrefsGameStore.withStorage(
        prefs,
        content: content,
      ).load())!.journalEntryIds,
      contains('j_letter'),
    );
  });
  test(
    'future versions are preserved and cannot be overwritten by autosave',
    () async {
      final future = initial.toJson()..['schemaVersion'] = 999;
      final prefs = TestPreferences()
        ..data['${PrefsGameStore.prefix}.a'] = envelope(jsonEncode(future), 1)
        ..data['${PrefsGameStore.prefix}.head'] = 'a:1';
      final before = Map.of(prefs.data);
      final store = PrefsGameStore.withStorage(prefs, content: content);
      expect(await store.load(), isNull);
      expect(store.recovery, SaveRecovery.unsupported);
      await expectLater(
        store.save(initial),
        throwsA(isA<UnsupportedSaveVersion>()),
      );
      expect(prefs.data, before);
      await store.clear();
      await store.save(initial);
      expect(await store.load(), isNotNull);
    },
  );
  test('partial, impossible and inconsistent progression never commits', () {
    final changes = <void Function(Map<String, Object?>)>[
      (j) => j.remove('inventory'),
      (j) => j['inventory'] = ['brass_winding_key'],
      (j) => j['currentRoomId'] = 'echo_vault',
      (j) => j['flags'] = {'mercy': 500},
      (j) => j['solvedPuzzleIds'] = ['p1_candle_moons'],
      (j) => j['endingId'] = 'seal_echo',
      (j) => j['openExitIds'] = ['hall_to_library'],
      (j) => j['inventory'] = <String>[],
      (j) => j['pendingChoiceIds'] = ['missing'],
      (j) => j['journalEntryIds'] = ['j_timeline'],
      (j) => j['inventory'] = ['wrens_letter', 'wrens_letter'],
    ];
    for (final change in changes) {
      final json = initial.toJson();
      change(json);
      expect(() => codec.decode(jsonEncode(json)), throwsA(anything));
    }
  });
  test('autosave writes are serialized and New Game commits after older pending writes', () async {
    final store = DelayedGameStore();
    final game = GameController(content, store: store);
    game.examine('h_portrait');
    game.inspectItem('brass_winding_key');
    await Future<void>.delayed(Duration.zero);
    expect(store.maximum, 1);
    expect(game.isSaving, isTrue);
    game.restart();
    store.first.complete();
    await game.flushSaves();
    expect(store.maximum, 1);
    expect(store.clears, 1);
    expect(store.completed.last.inventory, content.story.startItems);
    expect(game.isSaving, isFalse);
    expect(game.lastSaveError, isNull);
    game.dispose();
  });
  test('save errors do not corrupt the live game and can recover on the next mutation', () async {
    final prefs = TestPreferences();
    final store = PrefsGameStore.withStorage(prefs, content: content);
    await store.save(initial);
    prefs.failAt = prefs.writes + 1;
    final game = GameController(content, store: store);
    game.examine('h_portrait');
    await game.flushSaves();
    expect(game.hasItem('brass_winding_key'), isTrue);
    expect(game.lastSaveError, isNotNull);
    prefs.failAt = null;
    game.inspectItem('brass_winding_key');
    await game.flushSaves();
    expect(game.lastSaveError, isNull);
    expect(
      (await store.load())!.inspectedItemIds,
      contains('brass_winding_key'),
    );
    game.dispose();
  });
}
