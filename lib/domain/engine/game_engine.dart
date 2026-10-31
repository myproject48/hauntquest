import '../../content/definitions/choice_def.dart';
import '../../content/definitions/effect.dart';
import '../../content/definitions/puzzle_def.dart';
import '../../content/definitions/room_def.dart';
import '../../content/game_content.dart';
import '../hints/blocked_hints.dart';
import '../items/item_combinations.dart';
import '../models/game_state.dart';
import '../narrative/narrative_engine.dart';
import '../narrative/dialogue_record.dart';
import '../puzzles/puzzle_evaluator.dart';
import '../puzzles/puzzle_progress.dart';
import 'game_events.dart';

/// The outcome of one action: the new state, what happened, and text to show.
class EngineResult {
  const EngineResult(this.state, this.events, {this.message});

  final GameState state;
  final List<GameEvent> events;

  /// The main text to show for this action (a description, a success line).
  final String? message;

  ActionRejected? get rejection =>
      events.whereType<ActionRejected>().firstOrNull;
  bool get ok => rejection == null;

  List<String> get itemsAcquired => [
    for (final e in events.whereType<ItemAcquired>()) e.itemId,
  ];
  List<String> get exitsOpened => [
    for (final e in events.whereType<ExitOpened>()) e.exitId,
  ];
  String? get endingReached =>
      events.whereType<EndingReached>().firstOrNull?.endingId;
}

/// Where a puzzle stands for the player right now.
enum PuzzleAccess {
  /// Its object is locked, it is in another room, or it has a prerequisite.
  locked,

  /// Can be looked at, but needs an item the player does not carry.
  missingItems,

  /// Can be attempted.
  available,
  solved,
}

/// All game rules. Pure: no Flutter, no I/O, no randomness, no clock.
///
/// Every action returns a new [GameState]; rejected actions return the same
/// state with an [ActionRejected] event. Effects are idempotent: an item is
/// never granted twice and a solved puzzle never re-applies its rewards.
class GameEngine {
  GameEngine(this.content)
    : hints = BlockedHints(content),
      narrative = NarrativeEngine(content);

  final GameContent content;
  final BlockedHints hints;
  final NarrativeEngine narrative;

  // ------------------------------------------------------------ new game

  GameState newGame() {
    final story = content.story;
    return GameState(
      currentRoomId: story.startRoomId,
      visitedRoomIds: {story.startRoomId},
      inventory: story.startItems,
      acquiredItemIds: story.startItems.toSet(),
      flags: {for (final f in story.flags) f.id: f.initial},
    );
  }

  // -------------------------------------------------------------- queries

  RoomDef room(GameState s) => content.roomById(s.currentRoomId)!;

  bool isExitOpen(GameState s, ExitDef exit) =>
      exit.initiallyOpen || s.exitOpen(exit.id);

  bool canInteract(GameState s, HotspotDef h) =>
      h.requires?.evaluate(s) ?? true;

  PuzzleAccess puzzleAccess(GameState s, PuzzleDef p) {
    if (s.puzzleSolved(p.id)) return PuzzleAccess.solved;
    final hotspot = content.hotspotById(p.hotspotId);
    if (p.roomId != s.currentRoomId) return PuzzleAccess.locked;
    if (hotspot != null && !canInteract(s, hotspot)) return PuzzleAccess.locked;
    if (!(p.unlockWhen?.evaluate(s) ?? true)) return PuzzleAccess.locked;
    // Item puzzles are attempted by using an item, so they stay available and
    // report the wrong or missing item on use.
    if (p.kind != PuzzleKind.useItem && !p.requiresItems.every(s.hasItem)) {
      return PuzzleAccess.missingItems;
    }
    return PuzzleAccess.available;
  }

  /// Whether a conversation can be held now: it was triggered, or its object
  /// is in this room and usable.
  bool choiceAvailable(GameState s, ChoiceDef c) =>
      narrative.choiceAvailable(s, c);

  bool optionEnabled(GameState s, ChoiceOption o) =>
      narrative.optionEnabled(s, o);

  // -------------------------------------------------------------- actions

  /// Walks through an exit of the current room.
  EngineResult move(GameState s, String exitId) {
    if (s.endingId != null) {
      return _reject(s, RejectReason.gameOver, 'The story is over.');
    }
    final exit = content.exitById(exitId);
    if (exit == null) {
      return _reject(s, RejectReason.unknownTarget, 'There is no such way.');
    }
    if (exit.fromRoomId != s.currentRoomId) {
      return _reject(s, RejectReason.notHere, 'That way is not in this room.');
    }
    if (!isExitOpen(s, exit)) {
      return _reject(
        s,
        RejectReason.exitLocked,
        exit.lockedText ?? 'The way is blocked.',
        hint: hints.exit(exit, s),
      );
    }
    final first = !s.visitedRoom(exit.toRoomId);
    final next = s.copyWith(
      currentRoomId: exit.toRoomId,
      visitedRoomIds: {...s.visitedRoomIds, exit.toRoomId},
    );
    return EngineResult(next, [RoomEntered(exit.toRoomId, firstVisit: first)]);
  }

  /// Moves to a neighbouring room through whichever open exit leads there.
  EngineResult travelTo(GameState s, String roomId) {
    final exits = room(s).exits.where((e) => e.toRoomId == roomId).toList();
    if (exits.isEmpty) {
      return _reject(
        s,
        RejectReason.notHere,
        'You cannot reach that room from here.',
      );
    }
    final open = exits.where((e) => isExitOpen(s, e));
    return move(s, (open.isEmpty ? exits.first : open.first).id);
  }

  /// Looks at an object. The first look applies its discoveries.
  EngineResult examine(GameState s, String hotspotId) {
    if (s.endingId != null) {
      return _reject(s, RejectReason.gameOver, 'The story is over.');
    }
    final h = content.hotspotById(hotspotId);
    if (h == null) {
      return _reject(
        s,
        RejectReason.unknownTarget,
        'There is nothing like that here.',
      );
    }
    if (h.roomId != s.currentRoomId) {
      return _reject(s, RejectReason.notHere, 'That is not in this room.');
    }
    if (!canInteract(s, h)) {
      return _reject(
        s,
        RejectReason.hotspotLocked,
        h.lockedText ?? 'You cannot do that yet.',
        hint: hints.hotspot(h, s),
      );
    }
    final first = !s.examined(h.id);
    if (!first) {
      return EngineResult(s, [
        HotspotExamined(h.id, firstTime: false),
      ], message: h.repeatText.resolve(s));
    }
    // Describe using the state before the discovery, so the text matches it.
    final text = h.description.resolve(s);
    final events = <GameEvent>[HotspotExamined(h.id, firstTime: true)];
    var next = s.copyWith(examinedHotspotIds: {...s.examinedHotspotIds, h.id});
    next = _applyAll(next, h.onExamine, events);
    return EngineResult(next, events, message: text);
  }

  /// Marks an inventory item as looked at.
  EngineResult inspectItem(GameState s, String itemId) {
    if (s.endingId != null) {
      return _reject(s, RejectReason.gameOver, 'The story is over.');
    }
    if (!s.hasItem(itemId)) {
      return _reject(
        s,
        RejectReason.itemNotCarried,
        'You are not carrying that.',
      );
    }
    if (s.inspectedItemIds.contains(itemId)) return EngineResult(s, const []);
    return EngineResult(
      s.copyWith(inspectedItemIds: {...s.inspectedItemIds, itemId}),
      [ItemInspected(itemId)],
    );
  }

  /// Directly collects an item into inventory, preventing duplicate acquisition.
  EngineResult acquireItem(GameState s, String itemId) {
    if (s.endingId != null) {
      return _reject(s, RejectReason.gameOver, 'The story is over.');
    }
    if (content.itemById(itemId) == null) {
      return _reject(s, RejectReason.unknownTarget, 'There is no such item.');
    }
    if (s.wasAcquired(itemId)) {
      return _reject(
        s,
        RejectReason.itemAlreadyAcquired,
        'You have already acquired this item.',
      );
    }
    final events = <GameEvent>[];
    final next = _apply(s, GiveItem(itemId), events);
    return EngineResult(
      next,
      events,
      message: 'Added ${content.itemById(itemId)!.name} to inventory.',
    );
  }

  /// Attempts to combine two carried items according to known combination recipes.
  EngineResult combineItems(GameState s, String itemA, String itemB) {
    if (s.endingId != null) {
      return _reject(s, RejectReason.gameOver, 'The story is over.');
    }
    if (!s.hasItem(itemA) || !s.hasItem(itemB)) {
      return _reject(
        s,
        RejectReason.itemNotCarried,
        'You are not carrying both items.',
      );
    }
    if (itemA == itemB) {
      return _reject(
        s,
        RejectReason.cannotCombine,
        'You cannot combine an item with itself.',
      );
    }

    final recipe = ItemCombinations.find(itemA, itemB);
    if (recipe == null) {
      final feedback = ItemCombinations.describeInvalid(content, itemA, itemB);
      return _reject(s, RejectReason.cannotCombine, feedback);
    }

    final events = <GameEvent>[];
    var next = s;
    if (recipe.consumesItemA) {
      next = _apply(next, ConsumeItem(itemA), events);
    }
    if (recipe.consumesItemB) {
      next = _apply(next, ConsumeItem(itemB), events);
    }
    next = _apply(next, GiveItem(recipe.resultItemId), events);
    events.insert(0, ItemCombined(itemA, itemB, recipe.resultItemId));

    if (recipe.associatedPuzzleId != null &&
        !next.puzzleSolved(recipe.associatedPuzzleId!)) {
      final p = content.puzzleById(recipe.associatedPuzzleId!);
      if (p != null) {
        next = next.copyWith(
          solvedPuzzleIds: {...next.solvedPuzzleIds, p.id},
          examinedHotspotIds: {...next.examinedHotspotIds, p.hotspotId},
        );
        events.add(PuzzleSolved(p.id));
        for (final eff in p.onSolved) {
          if (eff is GiveItem && eff.id == recipe.resultItemId) continue;
          next = _apply(next, eff, events);
        }
      }
    }

    return EngineResult(next, events, message: recipe.successText);
  }

  /// Uses a carried item on an object.
  EngineResult useItem(GameState s, String itemId, String hotspotId) {
    if (s.endingId != null) {
      return _reject(s, RejectReason.gameOver, 'The story is over.');
    }
    final h = content.hotspotById(hotspotId);
    if (h == null || content.itemById(itemId) == null) {
      return _reject(s, RejectReason.unknownTarget, 'Nothing happens.');
    }
    if (h.roomId != s.currentRoomId) {
      return _reject(s, RejectReason.notHere, 'That is not in this room.');
    }
    if (!s.hasItem(itemId)) {
      return _reject(
        s,
        RejectReason.itemNotCarried,
        'You are not carrying that.',
      );
    }
    if (!canInteract(s, h)) {
      return _reject(
        s,
        RejectReason.hotspotLocked,
        h.lockedText ?? 'You cannot do that yet.',
        hint: hints.hotspot(h, s),
      );
    }

    // Item puzzles (for example winding the caretaker) are solved by use.
    final puzzle = h.puzzleId == null ? null : content.puzzleById(h.puzzleId!);
    if (puzzle != null &&
        puzzle.kind == PuzzleKind.useItem &&
        !s.puzzleSolved(puzzle.id)) {
      if (puzzle.config['itemId'] == itemId) {
        return submitPuzzle(s, puzzle.id, UseItemInput(itemId));
      }
      final attempted = _countAttempt(s, puzzle.id);
      return EngineResult(attempted.$1, [
        attempted.$2,
        ActionRejected(RejectReason.itemDoesNothing, h.wrongItemText),
      ], message: h.wrongItemText);
    }

    for (final rule in h.useRules.where((r) => r.itemId == itemId)) {
      if (!(rule.when?.evaluate(s) ?? true)) continue;
      final key = '${h.id}|$itemId';
      if (s.usedRuleKeys.contains(key)) {
        // Repeating is allowed (for example replaying a recording) but the
        // effects are applied only once.
        return EngineResult(s, [
          ItemUsed(itemId, h.id),
        ], message: rule.successText);
      }
      final events = <GameEvent>[ItemUsed(itemId, h.id)];
      var next = s.copyWith(
        usedRuleKeys: {...s.usedRuleKeys, key},
        examinedHotspotIds: {...s.examinedHotspotIds, h.id},
      );
      next = _applyAll(next, rule.effects, events);
      if (rule.consumeItem) next = _apply(next, ConsumeItem(itemId), events);
      return EngineResult(next, events, message: rule.successText);
    }
    return _reject(s, RejectReason.itemDoesNothing, h.wrongItemText);
  }

  /// Contextual hints remain available while story or inventory prerequisites
  /// are missing. Revealing one never edits the apparatus or solves it.
  EngineResult revealPuzzleHint(GameState s, String id) {
    final p = content.puzzleById(id);
    if (p == null ||
        p.roomId != s.currentRoomId ||
        s.puzzleSolved(id) ||
        s.endingId != null) {
      return _reject(
        s,
        RejectReason.puzzleUnavailable,
        'Hints are unavailable here.',
      );
    }
    final old = s.puzzleProgress[id];
    final tier = old?.hintTier ?? 0;
    if (tier >= 3) return EngineResult(s, const []);
    final progress = PuzzleProgress(
      input: old?.input ?? initialInputFor(p),
      hintTier: tier + 1,
    );
    return EngineResult(
      s.copyWith(puzzleProgress: {...s.puzzleProgress, id: progress}),
      const [],
    );
  }

  /// Keeps legal work in progress without evaluating or solving it.
  EngineResult savePuzzleProgress(
    GameState s,
    String id,
    PuzzleInput input,
    int hintTier,
  ) {
    final p = content.puzzleById(id);
    if (p == null ||
        puzzleAccess(s, p) != PuzzleAccess.available ||
        s.endingId != null ||
        !isLegalPuzzleInput(p, input) ||
        hintTier < 0 ||
        hintTier > 3) {
      return _reject(
        s,
        RejectReason.puzzleUnavailable,
        'That puzzle cannot be changed now.',
      );
    }
    // Round-trip to take an immutable snapshot of caller-owned collections.
    final progress = PuzzleProgress.fromJson(
      PuzzleProgress(input: input, hintTier: hintTier).toJson(),
    );
    return EngineResult(
      s.copyWith(puzzleProgress: {...s.puzzleProgress, id: progress}),
      const [],
    );
  }

  /// Checks a puzzle attempt and applies its rewards when correct.
  EngineResult submitPuzzle(GameState s, String puzzleId, PuzzleInput input) {
    final p = content.puzzleById(puzzleId);
    if (p == null) {
      return _reject(s, RejectReason.unknownTarget, 'There is no such puzzle.');
    }
    switch (puzzleAccess(s, p)) {
      case PuzzleAccess.solved:
        return _reject(
          s,
          RejectReason.puzzleSolved,
          'You have already solved this.',
        );
      case PuzzleAccess.locked:
        return _reject(
          s,
          RejectReason.puzzleUnavailable,
          'You cannot try this yet.',
          hint: hints.puzzle(p, s),
        );
      case PuzzleAccess.missingItems:
        return _reject(
          s,
          RejectReason.puzzleMissingItems,
          'Something is missing.',
          hint: hints.puzzle(p, s),
        );
      case PuzzleAccess.available:
        break;
    }
    if (p.kind == PuzzleKind.useItem &&
        input is UseItemInput &&
        !s.hasItem(input.itemId)) {
      return _reject(
        s,
        RejectReason.itemNotCarried,
        'You are not carrying that.',
        hint: hints.puzzle(p, s),
      );
    }

    if (s.endingId != null) {
      return _reject(s, RejectReason.gameOver, 'The story is over.');
    }
    if (!isLegalPuzzleInput(p, input)) {
      return _reject(
        s,
        RejectReason.puzzleUnavailable,
        'Use only the values marked on the apparatus.',
      );
    }
    final verdict = evaluatePuzzle(p, input);
    s = savePuzzleProgress(
      s,
      p.id,
      input,
      s.puzzleProgress[p.id]?.hintTier ?? 0,
    ).state;
    final (attempted, attemptEvent) = _countAttempt(s, p.id);
    final events = <GameEvent>[attemptEvent];
    if (verdict != Verdict.correct) {
      return EngineResult(
        attempted,
        events,
        message: verdict == Verdict.partial
            ? (p.partialText ?? p.incorrectText)
            : p.incorrectText,
      );
    }

    var next = attempted.copyWith(
      solvedPuzzleIds: {...attempted.solvedPuzzleIds, p.id},
      examinedHotspotIds: {...attempted.examinedHotspotIds, p.hotspotId},
    );
    events.add(PuzzleSolved(p.id));
    for (final id in p.consumesItems) {
      next = _apply(next, ConsumeItem(id), events);
    }
    next = _applyAll(next, p.onSolved, events);
    return EngineResult(next, events, message: p.successText);
  }

  /// Picks an answer in a conversation. The final choice ends the story.
  EngineResult resolveChoice(GameState s, String choiceId, String optionId) {
    if (s.endingId != null) {
      return _reject(s, RejectReason.gameOver, 'The story is over.');
    }
    final c = content.choiceById(choiceId);
    if (c == null) {
      return _reject(
        s,
        RejectReason.unknownTarget,
        'There is no such conversation.',
      );
    }
    if (!choiceAvailable(s, c)) {
      return _reject(
        s,
        RejectReason.choiceUnavailable,
        'That conversation is not open to you now.',
      );
    }
    final o = c.options.where((o) => o.id == optionId).firstOrNull;
    if (o == null) {
      return _reject(s, RejectReason.unknownTarget, 'There is no such answer.');
    }
    if (!optionEnabled(s, o)) {
      return _reject(
        s,
        RejectReason.optionDisabled,
        o.disabledReason ?? 'You cannot say that yet.',
      );
    }
    final record = DialogueRecord(
      prompt: c.prompt.resolve(s),
      response: o.responseFor(s),
    );
    final events = <GameEvent>[];
    var next = _applyAll(s, o.effects, events);
    next = next.copyWith(
      resolvedChoices: {...next.resolvedChoices, c.id: o.id},
      dialogueRecords: {...next.dialogueRecords, c.id: record},
      pendingChoiceIds: [...next.pendingChoiceIds]..remove(c.id),
    );
    events.add(ChoiceResolved(c.id, o.id));
    if (o.nextChoiceId case final nextId?) {
      next = _apply(next, StartChoice(nextId), events);
    }
    if (c.id == content.story.finalChoiceId) {
      final ending =
          content.resolveEnding(next) ?? content.story.endings.last.id;
      next = next.copyWith(endingId: ending);
      events.add(EndingReached(ending));
    }
    return EngineResult(next, events, message: record.response);
  }

  // -------------------------------------------------------------- effects

  GameState _applyAll(
    GameState s,
    Iterable<Effect> effects,
    List<GameEvent> out,
  ) {
    var next = s;
    for (final e in effects) {
      next = _apply(next, e, out);
    }
    return next;
  }

  /// Applies one effect. Idempotent: repeating it changes nothing.
  GameState _apply(GameState s, Effect e, List<GameEvent> out) {
    switch (e) {
      case GiveItem(:final id):
        if (s.wasAcquired(id)) return s;
        out.add(ItemAcquired(id));
        return s.copyWith(
          inventory: [...s.inventory, id],
          acquiredItemIds: {...s.acquiredItemIds, id},
        );
      case ConsumeItem(:final id):
        if (!s.hasItem(id)) return s;
        out.add(ItemConsumed(id));
        return s.copyWith(inventory: [...s.inventory]..remove(id));
      case SetFlag(:final id, :final value):
        return _setFlag(s, id, value, out);
      case AddFlag(:final id, :final amount):
        return _setFlag(s, id, s.flag(id) + amount, out);
      case OpenExit(:final id):
        if (s.exitOpen(id)) return s;
        out.add(ExitOpened(id));
        return s.copyWith(openExitIds: {...s.openExitIds, id});
      case StartChoice(:final id):
        if (s.choiceResolved(id) || s.pendingChoiceIds.contains(id)) return s;
        out.add(ChoiceStarted(id));
        return s.copyWith(pendingChoiceIds: [...s.pendingChoiceIds, id]);
    }
  }

  GameState _setFlag(GameState s, String id, int value, List<GameEvent> out) {
    final def = content.flagById(id);
    final clamped = def == null ? value : value.clamp(def.min, def.max);
    final before = s.flag(id);
    if (clamped == before) return s;
    out.add(FlagChanged(id, before, clamped));
    return s.copyWith(flags: {...s.flags, id: clamped});
  }

  (GameState, GameEvent) _countAttempt(GameState s, String puzzleId) {
    final n = (s.puzzleAttempts[puzzleId] ?? 0) + 1;
    return (
      s.copyWith(puzzleAttempts: {...s.puzzleAttempts, puzzleId: n}),
      PuzzleAttempted(puzzleId, n),
    );
  }

  EngineResult _reject(
    GameState s,
    RejectReason reason,
    String message, {
    String? hint,
  }) => EngineResult(s, [
    ActionRejected(reason, message, hint: hint),
  ], message: message);
}
