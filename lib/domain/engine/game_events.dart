/// Something that happened as the result of an action. The UI turns these into
/// feedback (banners, sounds later); the engine never calls the UI.
sealed class GameEvent {
  const GameEvent();
}

final class RoomEntered extends GameEvent {
  const RoomEntered(this.roomId, {required this.firstVisit});
  final String roomId;
  final bool firstVisit;
}

final class HotspotExamined extends GameEvent {
  const HotspotExamined(this.hotspotId, {required this.firstTime});
  final String hotspotId;
  final bool firstTime;
}

final class ItemAcquired extends GameEvent {
  const ItemAcquired(this.itemId);
  final String itemId;
}

final class ItemConsumed extends GameEvent {
  const ItemConsumed(this.itemId);
  final String itemId;
}

final class ItemInspected extends GameEvent {
  const ItemInspected(this.itemId);
  final String itemId;
}

final class ExitOpened extends GameEvent {
  const ExitOpened(this.exitId);
  final String exitId;
}

final class FlagChanged extends GameEvent {
  const FlagChanged(this.flagId, this.from, this.to);
  final String flagId;
  final int from;
  final int to;
}

final class ItemUsed extends GameEvent {
  const ItemUsed(this.itemId, this.hotspotId);
  final String itemId;
  final String hotspotId;
}

final class PuzzleAttempted extends GameEvent {
  const PuzzleAttempted(this.puzzleId, this.attempt);
  final String puzzleId;
  final int attempt;
}

final class PuzzleSolved extends GameEvent {
  const PuzzleSolved(this.puzzleId);
  final String puzzleId;
}

final class ChoiceStarted extends GameEvent {
  const ChoiceStarted(this.choiceId);
  final String choiceId;
}

final class ChoiceResolved extends GameEvent {
  const ChoiceResolved(this.choiceId, this.optionId);
  final String choiceId;
  final String optionId;
}

final class EndingReached extends GameEvent {
  const EndingReached(this.endingId);
  final String endingId;
}

final class ItemCombined extends GameEvent {
  const ItemCombined(this.firstItemId, this.secondItemId, this.resultItemId);
  final String firstItemId;
  final String secondItemId;
  final String resultItemId;
}

/// Why an action was refused. The state is unchanged.
enum RejectReason {
  unknownTarget,
  notHere,
  exitLocked,
  hotspotLocked,
  itemNotCarried,
  itemDoesNothing,
  cannotCombine,
  itemAlreadyAcquired,
  puzzleUnavailable,
  puzzleSolved,
  puzzleMissingItems,
  choiceUnavailable,
  optionDisabled,
  gameOver,
}

final class ActionRejected extends GameEvent {
  const ActionRejected(this.reason, this.message, {this.hint});
  final RejectReason reason;

  /// In-world explanation, safe to show the player.
  final String message;

  /// Optional gentle nudge toward what is needed. Never the full solution.
  final String? hint;
}
