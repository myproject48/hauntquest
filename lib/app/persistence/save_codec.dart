import 'dart:convert';

import '../../content/definitions/effect.dart';
import '../../content/game_content.dart';
import '../../domain/models/game_state.dart';
import '../../domain/narrative/narrative_engine.dart';
import '../../domain/puzzles/puzzle_progress.dart';

class UnsupportedSaveVersion implements Exception {
  const UnsupportedSaveVersion(this.version);
  final int version;
}

/// Validates whole snapshots before accepting any field. Supported v1 saves
/// migrate to v2; unknown future formats are preserved instead of overwritten.
class SaveCodec {
  const SaveCodec([this.content]);
  final GameContent? content;
  String encode(GameState state) {
    if (state.schemaVersion < 1 ||
        state.schemaVersion > GameState.currentSchemaVersion) {
      throw UnsupportedSaveVersion(state.schemaVersion);
    }
    final json = state.toJson();
    json['schemaVersion'] = GameState.currentSchemaVersion;
    if (content case final c?) {
      json['journalEntryIds'] = {
        ...state.journalEntryIds,
        ...NarrativeEngine(c).journal(state).map((e) => e.id),
      }.toList()..sort();
    }
    decode(jsonEncode(json)); // Never commit a structurally invalid snapshot.
    return jsonEncode(json);
  }

  GameState decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Save is not an object');
    }
    final json = Map<String, Object?>.of(decoded);
    final version = json['schemaVersion'] ?? 1;
    if (version is! int || version < 1) {
      throw const FormatException('Invalid save version');
    }
    if (version > GameState.currentSchemaVersion) {
      throw UnsupportedSaveVersion(version);
    }
    for (final key in [
      'currentRoomId',
      'inventory',
      'solvedPuzzleIds',
      'flags',
    ]) {
      if (!json.containsKey(key)) {
        throw FormatException('Incomplete save: $key');
      }
    }
    final listKeys = [
      'visitedRoomIds',
      'openExitIds',
      'inventory',
      'acquiredItemIds',
      'inspectedItemIds',
      'examinedHotspotIds',
      'usedRuleKeys',
      'solvedPuzzleIds',
      'pendingChoiceIds',
      'journalEntryIds',
    ];
    final mapKeys = [
      'puzzleAttempts',
      'puzzleProgress',
      'flags',
      'resolvedChoices',
      'dialogueRecords',
    ];
    if (json['currentRoomId'] is! String ||
        (json['endingId'] != null && json['endingId'] is! String)) {
      throw const FormatException('Invalid save identifiers');
    }
    for (final key in listKeys) {
      if (version == 2 && !json.containsKey(key)) {
        throw FormatException('Incomplete save: $key');
      }
      if (json[key] == null && version == 1) json[key] = <String>[];
      final value = json[key];
      if (value is! List ||
          value.any((v) => v is! String) ||
          value.toSet().length != value.length) {
        throw FormatException('Invalid save list: $key');
      }
    }
    for (final key in mapKeys) {
      if (version == 2 && !json.containsKey(key)) {
        throw FormatException('Incomplete save: $key');
      }
      if (json[key] == null && version == 1 && key != 'dialogueRecords') {
        json[key] = <String, Object?>{};
      }
      if (json[key] != null && json[key] is! Map) {
        throw FormatException('Invalid save map: $key');
      }
    }
    if (version == 1) {
      json['visitedRoomIds'] = {
        ...(json['visitedRoomIds'] as List).cast<String>(),
        json['currentRoomId'] as String,
        if (content != null) content!.story.startRoomId,
      }.toList();
      json['acquiredItemIds'] = {
        ...(json['acquiredItemIds'] as List).cast<String>(),
        ...(json['inventory'] as List).cast<String>(),
      }.toList();
    }
    for (final value in (json['puzzleProgress'] as Map).values) {
      if (value is! Map ||
          value['hintTier'] is! int ||
          value['hintTier'] < 0 ||
          value['hintTier'] > 3) {
        throw const FormatException('Invalid hint tier');
      }
    }
    final state = GameState.fromJson(json);
    _validate(state);
    return state;
  }

  void _validate(GameState s) {
    void require(bool condition, String why) {
      if (!condition) throw FormatException(why);
    }

    require(s.currentRoomId.isNotEmpty, 'Missing room');
    require(
      s.visitedRoomIds.contains(s.currentRoomId),
      'Current room was not visited',
    );
    require(
      s.acquiredItemIds.containsAll(s.inventory),
      'Inventory was not acquired',
    );
    require(
      s.acquiredItemIds.containsAll(s.inspectedItemIds),
      'Unknown inspected item',
    );
    require(
      s.puzzleAttempts.values.every((v) => v >= 0),
      'Negative attempt count',
    );
    require(
      s.resolvedChoices.keys.toSet().containsAll(s.dialogueRecords.keys),
      'Transcript without choice',
    );
    require(
      !s.pendingChoiceIds.any(s.choiceResolved),
      'Resolved choice still pending',
    );
    final c = content;
    if (c == null) return;
    require(
      c.roomById(s.currentRoomId) != null &&
          s.visitedRoomIds.every((id) => c.roomById(id) != null),
      'Unknown room',
    );
    require(
      s.acquiredItemIds.every((id) => c.itemById(id) != null),
      'Unknown item',
    );
    require(
      s.openExitIds.every((id) => c.exitById(id) != null),
      'Unknown exit',
    );
    require(
      s.examinedHotspotIds.every((id) => c.hotspotById(id) != null),
      'Unknown hotspot',
    );
    require(
      s.solvedPuzzleIds.every((id) => c.puzzleById(id) != null),
      'Unknown puzzle',
    );
    require(
      s.journalEntryIds.every(
        (id) => c.story.journalEntries.any(
          (e) => e.id == id && e.unlockWhen.evaluate(s),
        ),
      ),
      'Invalid journal discovery',
    );
    for (final entry in s.flags.entries) {
      final flag = c.flagById(entry.key);
      require(
        flag != null && entry.value >= flag.min && entry.value <= flag.max,
        'Invalid narrative flag',
      );
    }
    for (final entry in s.resolvedChoices.entries) {
      require(
        c.choiceById(entry.key)?.options.any((o) => o.id == entry.value) ??
            false,
        'Unknown dialogue option',
      );
    }
    require(
      s.pendingChoiceIds.every((id) => c.choiceById(id) != null),
      'Unknown pending dialogue',
    );
    require(
      s.puzzleAttempts.keys.every((id) => c.puzzleById(id) != null),
      'Unknown attempt',
    );
    for (final entry in s.puzzleProgress.entries) {
      final p = c.puzzleById(entry.key);
      require(
        p != null &&
            isLegalPuzzleInput(p, entry.value.input) &&
            entry.value.hintTier >= 0 &&
            entry.value.hintTier <= 3,
        'Invalid puzzle draft',
      );
    }
    for (final key in s.usedRuleKeys) {
      final parts = key.split('|');
      require(
        parts.length == 2 &&
            (c
                    .hotspotById(parts.first)
                    ?.useRules
                    .any((r) => r.itemId == parts.last) ??
                false),
        'Unknown use rule',
      );
    }
    require(
      c.story.startItems.every(s.wasAcquired),
      'Missing starting evidence',
    );
    for (final item in s.consumedItemIds) {
      final consumedByPuzzle = c.puzzles.any(
        (p) => s.puzzleSolved(p.id) && p.consumesItems.contains(item),
      );
      final consumedByRule = c.allHotspots.any(
        (h) => h.useRules.any(
          (r) =>
              r.itemId == item &&
              r.consumeItem &&
              s.usedRuleKeys.contains('${h.id}|$item'),
        ),
      );
      require(
        consumedByPuzzle || consumedByRule,
        'Item disappeared without a completed action',
      );
    }
    for (final id in s.openExitIds) {
      final initial = c.exitById(id)!.initiallyOpen;
      final puzzle = c.puzzles.any(
        (p) =>
            s.puzzleSolved(p.id) &&
            p.onSolved.any((e) => e is OpenExit && e.id == id),
      );
      final hotspot = c.allHotspots.any(
        (h) =>
            s.examined(h.id) &&
            h.onExamine.any((e) => e is OpenExit && e.id == id),
      );
      final rule = c.allHotspots.any(
        (h) => h.useRules.any(
          (r) =>
              s.usedRuleKeys.contains('${h.id}|${r.itemId}') &&
              r.effects.any((e) => e is OpenExit && e.id == id),
        ),
      );
      final choice = c.choices.any(
        (c) => c.options.any(
          (o) =>
              s.resolvedChoices[c.id] == o.id &&
              o.effects.any((e) => e is OpenExit && e.id == id),
        ),
      );
      require(
        initial || puzzle || hotspot || rule || choice,
        'Exit opened without a completed action',
      );
    }
    final reachable = {c.story.startRoomId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final e in c.allExits) {
        if (reachable.contains(e.fromRoomId) &&
            (e.initiallyOpen || s.exitOpen(e.id)) &&
            reachable.add(e.toRoomId)) {
          changed = true;
        }
      }
    }
    require(
      reachable.containsAll(s.visitedRoomIds),
      'Room progression is disconnected',
    );
    for (final id in s.solvedPuzzleIds) {
      final p = c.puzzleById(id)!;
      require(
        s.examined(p.hotspotId) && s.visitedRoom(p.roomId),
        'Puzzle lacks discovery',
      );
      for (final effect in p.onSolved) {
        if (effect is OpenExit) {
          require(s.exitOpen(effect.id), 'Solved puzzle has missing exit');
        }
        if (effect is GiveItem) {
          require(s.wasAcquired(effect.id), 'Solved puzzle has missing reward');
        }
      }
      require(
        p.consumesItems.every((id) => s.wasAcquired(id) && !s.hasItem(id)),
        'Puzzle consumption is incomplete',
      );
    }
    require(
      (s.endingId != null) == s.choiceResolved(c.story.finalChoiceId),
      'Incomplete ending transaction',
    );
    if (s.endingId != null) {
      require(
        c.endingById(s.endingId!) != null &&
            s.choiceResolved(c.story.finalChoiceId) &&
            c.resolveEnding(s) == s.endingId,
        'Ending disagrees with final choice',
      );
    }
  }
}
