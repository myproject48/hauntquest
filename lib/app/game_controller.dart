import 'package:flutter/foundation.dart';

import 'game_store.dart';
import '../content/definitions/choice_def.dart';
import '../content/definitions/progress_view.dart';
import '../content/definitions/puzzle_def.dart';
import '../content/definitions/room_def.dart';
import '../content/game_content.dart';
import '../domain/engine/game_engine.dart';
import '../domain/engine/game_events.dart';
import '../domain/models/game_state.dart';
import '../domain/puzzles/puzzle_evaluator.dart';

/// What kind of feedback a [FeedbackNote] carries, for its icon.
enum FeedbackKind { item, path, truth, info }

/// A short message shown after an action, for example "Added: Brass Key".
@immutable
class FeedbackNote {
  const FeedbackNote(this.serial, this.kind, this.text);

  /// Increases with every note, so the same text twice still animates.
  final int serial;
  final FeedbackKind kind;
  final String text;
}

/// Owns the current [GameState] and runs every action through [GameEngine].
///
/// Every mutation is saved through GameStore, including unfinished puzzle
/// drafts, so navigation and application restarts preserve progress.
class GamePulse {
  GamePulse(this.serial, List<GameEvent> events)
    : events = List.unmodifiable(events);
  final int serial;
  final List<GameEvent> events;
}

class GameController extends ChangeNotifier implements ProgressView {
  GameController(this.content, {this.store, GameState? initial})
    : engine = GameEngine(content) {
    _state = initial ?? engine.newGame();
  }

  final GameContent content;
  final GameEngine engine;
  final GameStore? store;
  late GameState _state;

  /// The real playthrough, kept aside while review mode is on.
  GameState? _beforeReview;

  final ValueNotifier<FeedbackNote?> feedback = ValueNotifier(null);
  int _serial = 0;
  final ValueNotifier<GamePulse?> pulses = ValueNotifier(null);
  int _pulseSerial = 0;
  Future<void> _saveQueue = Future.value();
  Object? _lastSaveError;
  bool _disposed = false;
  int _pendingSaves = 0;
  Object? get lastSaveError => _lastSaveError;
  bool get isSaving => _pendingSaves > 0;
  Future<void> flushSaves() => _saveQueue;
  Future<void> retrySave() {
    _saveState();
    return flushSaves();
  }

  bool get needsNewGameConfirmation =>
      inProgress ||
      endingId != null ||
      (store is SaveDiagnostics &&
          (store as SaveDiagnostics).hasStoredProgress);
  SaveRecovery get saveRecovery => store is SaveDiagnostics
      ? (store as SaveDiagnostics).recovery
      : SaveRecovery.missing;

  GameState get state => _state;

  // -------------------------------------------------------------- queries

  String get currentRoomId => _state.currentRoomId;
  RoomDef get currentRoom => engine.room(_state);
  List<String> get inventory => _state.inventory;
  String? get endingId => _state.endingId;
  bool isVisited(String roomId) => _state.visitedRoom(roomId);
  bool canUseExit(ExitDef exit) => engine.isExitOpen(_state, exit);
  bool canInteract(HotspotDef h) => engine.canInteract(_state, h);
  PuzzleAccess puzzleAccess(PuzzleDef p) => engine.puzzleAccess(_state, p);
  bool choiceAvailable(ChoiceDef c) => engine.choiceAvailable(_state, c);
  bool optionEnabled(ChoiceOption o) => engine.optionEnabled(_state, o);

  /// A journey has been started and not finished this session.
  bool get inProgress =>
      !reviewMode &&
      _state.endingId == null &&
      (_state.visitedRoomIds.length > 1 ||
          _state.examinedHotspotIds.isNotEmpty ||
          _state.solvedPuzzleIds.isNotEmpty ||
          _state.puzzleAttempts.isNotEmpty);

  /// Conversations triggered by an action and waiting to be held.
  String? get nextPendingChoice => _state.pendingChoiceIds.where((id) {
    final choice = content.choiceById(id);
    return choice != null && engine.choiceAvailable(_state, choice);
  }).firstOrNull;

  /// Whether every discovery of this object has been taken.
  bool hotspotDepleted(HotspotDef h) =>
      _state.examined(h.id) &&
      (h.puzzleId == null || _state.puzzleSolved(h.puzzleId!)) &&
      (h.choiceId == null || _state.choiceResolved(h.choiceId!));

  /// People the player has met or learned about.
  Set<String> get knownCharacterIds {
    if (reviewMode) return content.story.characters.map((c) => c.id).toSet();
    final s = _state;
    return {
      'wren',
      for (final c in content.choices)
        if (s.choiceResolved(c.id)) c.speakerId,
      if (s.puzzleSolved('p2_wake_tallow')) 'tallow',
      if (s.examined('h_portrait') || s.wasAcquired('ottoline_journal'))
        'ottoline',
      if (s.examined('l_ledger') || s.choiceResolved('c_maul_bargain')) 'maul',
      if (s.examined('w_horn') ||
          s.choiceResolved('c_echo_whisper') ||
          s.visitedRoom('echo_vault'))
        'echo',
    };
  }

  // -------------------------------------------------------------- actions

  EngineResult move(String exitId) => _run(engine.move(_state, exitId));

  /// Moves to a neighbouring room (used by the map). Returns whether it worked.
  bool moveTo(String roomId) {
    if (roomId == currentRoomId) return true;
    if (reviewMode && content.roomById(roomId) != null) {
      // Review mode may jump anywhere to inspect a room.
      _state = _state.copyWith(currentRoomId: roomId);
      notifyListeners();
      return true;
    }
    return _run(engine.travelTo(_state, roomId)).ok;
  }

  EngineResult examine(String hotspotId) =>
      _run(engine.examine(_state, hotspotId));
  EngineResult useItem(String itemId, String hotspotId) =>
      _run(engine.useItem(_state, itemId, hotspotId));
  EngineResult inspectItem(String itemId) =>
      _run(engine.inspectItem(_state, itemId));
  EngineResult combineItems(String itemA, String itemB) =>
      _run(engine.combineItems(_state, itemA, itemB));
  EngineResult acquireItem(String itemId) =>
      _run(engine.acquireItem(_state, itemId));
  EngineResult submitPuzzle(String puzzleId, PuzzleInput input) =>
      _run(engine.submitPuzzle(_state, puzzleId, input));
  EngineResult revealPuzzleHint(String id) =>
      _run(engine.revealPuzzleHint(_state, id));
  EngineResult savePuzzleProgress(String id, PuzzleInput input, int hintTier) =>
      _run(engine.savePuzzleProgress(_state, id, input, hintTier));
  EngineResult resolveChoice(String choiceId, String optionId) =>
      _run(engine.resolveChoice(_state, choiceId, optionId));

  /// Starts the story over.
  void restart() {
    _beforeReview = null;
    _state = engine.newGame();
    feedback.value = null;
    _saveState(clearFirst: true);
    pulses.value = GamePulse(++_pulseSerial, const []);
    notifyListeners();
  }

  EngineResult _run(EngineResult r) {
    if (!identical(r.state, _state)) {
      _state = r.state;
      _saveState();
      notifyListeners();
    }
    if (r.events.isNotEmpty) pulses.value = GamePulse(++_pulseSerial, r.events);
    final note = _noteFor(r.events);
    if (note != null) feedback.value = note;
    return r;
  }

  void _saveState({bool clearFirst = false}) {
    if (store == null || reviewMode) return;
    final snapshot = _state;
    _pendingSaves++;
    _saveQueue = _saveQueue.then((_) async {
      try {
        if (clearFirst) await store!.clear();
        await store!.save(snapshot);
        _lastSaveError = null;
      } catch (error) {
        _lastSaveError = error;
      } finally {
        _pendingSaves--;
        if (!_disposed) notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    feedback.dispose();
    pulses.dispose();
    super.dispose();
  }

  FeedbackNote? _noteFor(List<GameEvent> events) {
    final parts = <(FeedbackKind, String)>[];
    for (final e in events) {
      switch (e) {
        case ItemAcquired(:final itemId):
          parts.add((
            FeedbackKind.item,
            'Added to inventory: ${content.itemById(itemId)?.name ?? itemId}',
          ));
        case ItemCombined(:final resultItemId):
          parts.add((
            FeedbackKind.item,
            'Combined items: ${content.itemById(resultItemId)?.name ?? resultItemId}',
          ));
        case ExitOpened(:final exitId):
          final exit = content.exitById(exitId);
          final to = exit == null
              ? null
              : content.roomById(exit.toRoomId)?.name;
          parts.add((
            FeedbackKind.path,
            'A way opens${to == null ? '' : ' to the $to'}',
          ));
        case FlagChanged(:final flagId, :final from, :final to)
            when flagId == 'truthFragments' && to > from:
          parts.add((
            FeedbackKind.truth,
            'You learned more of Ottoline\'s story',
          ));
        default:
          break;
      }
    }
    if (parts.isEmpty) return null;
    return FeedbackNote(
      ++_serial,
      parts.first.$1,
      parts.map((p) => p.$2).join('  ·  '),
    );
  }

  // ---------------------------------------------------------- review mode

  /// Review mode, for checking art and writing: every room visited, every
  /// exit open, every item carried. Puzzles stay unsolved. Turning it off
  /// restores the real playthrough exactly. Not a gameplay feature.
  bool get reviewMode => _beforeReview != null;

  set reviewMode(bool on) {
    if (on == reviewMode) return;
    if (on) {
      _beforeReview = _state;
      _state = _state.copyWith(
        visitedRoomIds: content.rooms.map((r) => r.id).toSet(),
        openExitIds: content.allExits.map((e) => e.id).toSet(),
        inventory: content.items.map((i) => i.id).toList(),
        acquiredItemIds: content.items.map((i) => i.id).toSet(),
        flags: {..._state.flags, 'cylinderPlayed': 1, 'engineRestored': 1},
      );
    } else {
      _state = _beforeReview!;
      _beforeReview = null;
    }
    notifyListeners();
  }

  // --------------------------------------------------------- ProgressView

  @override
  bool hasItem(String id) => _state.hasItem(id);
  @override
  bool puzzleSolved(String id) => _state.puzzleSolved(id);
  @override
  int flag(String id) => _state.flag(id);
  @override
  bool exitOpen(String id) => _state.exitOpen(id);
  @override
  bool examined(String id) => _state.examined(id);
  @override
  bool choiceResolved(String id) => _state.choiceResolved(id);
  @override
  bool visitedRoom(String id) => _state.visitedRoom(id);
}
