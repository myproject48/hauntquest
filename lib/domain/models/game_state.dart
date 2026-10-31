import '../../content/definitions/progress_view.dart';
import '../puzzles/puzzle_progress.dart';
import '../narrative/dialogue_record.dart';

/// The complete, immutable state of one playthrough.
///
/// Every change goes through `GameEngine`, which returns a new instance.
/// Serializes to JSON with primitive types only.
class GameState implements ProgressView {
  GameState({
    required this.currentRoomId,
    Set<String> visitedRoomIds = const {},
    Set<String> openExitIds = const {},
    List<String> inventory = const [],
    Set<String> acquiredItemIds = const {},
    Set<String> inspectedItemIds = const {},
    Set<String> examinedHotspotIds = const {},
    Set<String> usedRuleKeys = const {},
    Set<String> solvedPuzzleIds = const {},
    Set<String> journalEntryIds = const {},
    Map<String, int> puzzleAttempts = const {},
    Map<String, PuzzleProgress> puzzleProgress = const {},
    Map<String, int> flags = const {},
    Map<String, String> resolvedChoices = const {},
    Map<String, DialogueRecord> dialogueRecords = const {},
    List<String> pendingChoiceIds = const [],
    this.endingId,
    this.schemaVersion = currentSchemaVersion,
  }) : visitedRoomIds = Set.unmodifiable(visitedRoomIds),
       openExitIds = Set.unmodifiable(openExitIds),
       inventory = List.unmodifiable(inventory),
       acquiredItemIds = Set.unmodifiable(acquiredItemIds),
       inspectedItemIds = Set.unmodifiable(inspectedItemIds),
       examinedHotspotIds = Set.unmodifiable(examinedHotspotIds),
       usedRuleKeys = Set.unmodifiable(usedRuleKeys),
       solvedPuzzleIds = Set.unmodifiable(solvedPuzzleIds),
       journalEntryIds = Set.unmodifiable(journalEntryIds),
       puzzleAttempts = Map.unmodifiable(puzzleAttempts),
       puzzleProgress = Map.unmodifiable(puzzleProgress),
       flags = Map.unmodifiable(flags),
       resolvedChoices = Map.unmodifiable(resolvedChoices),
       dialogueRecords = Map.unmodifiable(dialogueRecords),
       pendingChoiceIds = List.unmodifiable(pendingChoiceIds);

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final String currentRoomId;
  final Set<String> visitedRoomIds;

  /// Exits opened during play. Exits that start open are not listed.
  final Set<String> openExitIds;

  /// Items carried now, in the order they were found.
  final List<String> inventory;

  /// Every item ever received, including consumed ones. Prevents an item from
  /// being granted twice.
  final Set<String> acquiredItemIds;
  final Set<String> inspectedItemIds;
  final Set<String> examinedHotspotIds;

  /// Item-on-object rules already applied, as `hotspotId|itemId`.
  final Set<String> usedRuleKeys;
  final Set<String> solvedPuzzleIds;
  final Set<String> journalEntryIds;
  final Map<String, int> puzzleAttempts;
  final Map<String, PuzzleProgress> puzzleProgress;
  final Map<String, int> flags;

  /// Choice id to the option id picked.
  final Map<String, String> resolvedChoices;
  final Map<String, DialogueRecord> dialogueRecords;

  /// Conversations that have been triggered and are waiting to be held.
  final List<String> pendingChoiceIds;

  /// Set once the final choice is made.
  final String? endingId;

  /// Items consumed by puzzles or use rules.
  Set<String> get consumedItemIds =>
      acquiredItemIds.difference(inventory.toSet());

  // ---------------------------------------------------------- ProgressView

  @override
  bool hasItem(String id) => inventory.contains(id);
  @override
  bool puzzleSolved(String id) => solvedPuzzleIds.contains(id);

  /// Flags not yet set read as 0. The engine seeds declared initial values.
  @override
  int flag(String id) => flags[id] ?? 0;
  @override
  bool exitOpen(String id) => openExitIds.contains(id);
  @override
  bool examined(String id) => examinedHotspotIds.contains(id);
  @override
  bool choiceResolved(String id) => resolvedChoices.containsKey(id);
  @override
  bool visitedRoom(String id) => visitedRoomIds.contains(id);

  bool wasAcquired(String id) => acquiredItemIds.contains(id);

  // -------------------------------------------------------------- copying

  GameState copyWith({
    String? currentRoomId,
    Set<String>? visitedRoomIds,
    Set<String>? openExitIds,
    List<String>? inventory,
    Set<String>? acquiredItemIds,
    Set<String>? inspectedItemIds,
    Set<String>? examinedHotspotIds,
    Set<String>? usedRuleKeys,
    Set<String>? solvedPuzzleIds,
    Set<String>? journalEntryIds,
    Map<String, int>? puzzleAttempts,
    Map<String, PuzzleProgress>? puzzleProgress,
    Map<String, int>? flags,
    Map<String, String>? resolvedChoices,
    Map<String, DialogueRecord>? dialogueRecords,
    List<String>? pendingChoiceIds,
    String? endingId,
  }) => GameState(
    schemaVersion: schemaVersion,
    currentRoomId: currentRoomId ?? this.currentRoomId,
    visitedRoomIds: visitedRoomIds ?? this.visitedRoomIds,
    openExitIds: openExitIds ?? this.openExitIds,
    inventory: inventory ?? this.inventory,
    acquiredItemIds: acquiredItemIds ?? this.acquiredItemIds,
    inspectedItemIds: inspectedItemIds ?? this.inspectedItemIds,
    examinedHotspotIds: examinedHotspotIds ?? this.examinedHotspotIds,
    usedRuleKeys: usedRuleKeys ?? this.usedRuleKeys,
    solvedPuzzleIds: solvedPuzzleIds ?? this.solvedPuzzleIds,
    journalEntryIds: journalEntryIds ?? this.journalEntryIds,
    puzzleAttempts: puzzleAttempts ?? this.puzzleAttempts,
    puzzleProgress: puzzleProgress ?? this.puzzleProgress,
    flags: flags ?? this.flags,
    resolvedChoices: resolvedChoices ?? this.resolvedChoices,
    dialogueRecords: dialogueRecords ?? this.dialogueRecords,
    pendingChoiceIds: pendingChoiceIds ?? this.pendingChoiceIds,
    endingId: endingId ?? this.endingId,
  );

  // ---------------------------------------------------------------- JSON

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'currentRoomId': currentRoomId,
    'visitedRoomIds': _sorted(visitedRoomIds),
    'openExitIds': _sorted(openExitIds),
    'inventory': inventory,
    'acquiredItemIds': _sorted(acquiredItemIds),
    'inspectedItemIds': _sorted(inspectedItemIds),
    'examinedHotspotIds': _sorted(examinedHotspotIds),
    'usedRuleKeys': _sorted(usedRuleKeys),
    'solvedPuzzleIds': _sorted(solvedPuzzleIds),
    'journalEntryIds': _sorted(journalEntryIds),
    'puzzleAttempts': puzzleAttempts,
    'puzzleProgress': {
      for (final e in puzzleProgress.entries) e.key: e.value.toJson(),
    },
    'flags': flags,
    'resolvedChoices': resolvedChoices,
    'dialogueRecords': {
      for (final e in dialogueRecords.entries) e.key: e.value.toJson(),
    },
    'pendingChoiceIds': pendingChoiceIds,
    'endingId': endingId,
  };

  factory GameState.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'] ?? 1;
    if (version is! int || version < 1 || version > currentSchemaVersion) {
      throw const FormatException('Unsupported save schema');
    }
    List<String> strings(String key) =>
        (json[key] as List? ?? const []).cast<String>();
    Map<String, V> map<V>(String key) =>
        (json[key] as Map? ?? const {}).cast<String, V>();
    return GameState(
      schemaVersion: currentSchemaVersion,
      currentRoomId: json['currentRoomId']! as String,
      visitedRoomIds: strings('visitedRoomIds').toSet(),
      openExitIds: strings('openExitIds').toSet(),
      inventory: strings('inventory'),
      acquiredItemIds: strings('acquiredItemIds').toSet(),
      inspectedItemIds: strings('inspectedItemIds').toSet(),
      examinedHotspotIds: strings('examinedHotspotIds').toSet(),
      usedRuleKeys: strings('usedRuleKeys').toSet(),
      solvedPuzzleIds: strings('solvedPuzzleIds').toSet(),
      journalEntryIds: strings('journalEntryIds').toSet(),
      puzzleAttempts: map<int>('puzzleAttempts'),
      puzzleProgress: {
        for (final e in (json['puzzleProgress'] as Map? ?? {}).entries)
          e.key as String: PuzzleProgress.fromJson(
            (e.value as Map).cast<String, Object?>(),
          ),
      },
      flags: map<int>('flags'),
      resolvedChoices: {
        for (final e in map<String>('resolvedChoices').entries)
          e.key: _migrateOption(e.value),
      },
      dialogueRecords: {
        for (final e in (json['dialogueRecords'] as Map? ?? {}).entries)
          e.key as String: DialogueRecord.fromJson(
            (e.value as Map).cast<String, Object?>(),
          ),
      },
      pendingChoiceIds: {
        ...strings('pendingChoiceIds'),
        if (!json.containsKey('dialogueRecords') && json['endingId'] == null)
          for (final pair in const [
            ['c_tallow_welcome', 'c_tallow_memory'],
            ['c_echo_whisper', 'c_echo_identity'],
            ['c_maul_bargain', 'c_maul_terms'],
          ])
            if (map<String>('resolvedChoices').containsKey(pair.first) &&
                !map<String>('resolvedChoices').containsKey(pair.last))
              pair.last,
      }.toList(),
      endingId: _migrateEnding(json['endingId'] as String?),
    );
  }

  static String _migrateOption(String id) => switch (id) {
    'ef_home' => 'ef_guardian',
    'ef_claim' => 'ef_seal',
    _ => id,
  };
  static String? _migrateEnding(String? id) => switch (id) {
    'quiet_dawn' => 'release_echo',
    'homecoming' => 'echo_guardian',
    'keepers_chair' => 'seal_echo',
    _ => id,
  };

  static List<String> _sorted(Set<String> s) => s.toList()..sort();

  @override
  bool operator ==(Object other) =>
      other is GameState && _deepEq(other.toJson(), toJson());

  @override
  int get hashCode => Object.hash(
    currentRoomId,
    inventory.length,
    solvedPuzzleIds.length,
    examinedHotspotIds.length,
    endingId,
  );

  static bool _deepEq(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEq(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
