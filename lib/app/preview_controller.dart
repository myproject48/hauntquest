import 'package:flutter/foundation.dart';

import '../content/definitions/progress_view.dart';
import '../content/definitions/room_def.dart';
import '../content/game_content.dart';

/// Temporary, read-only stand-in for the future `GameController`.
///
/// It lets the screens show real rooms, items, puzzles and dialogue from the
/// content files. It deliberately contains NO gameplay rules: it never applies
/// effects, never records solved puzzles or choices, and never grants items.
/// The only things the player can change are which room they are viewing and,
/// in review mode, whether everything is revealed. Replace with the real game
/// state once the engine exists (tasks.md, tasks 4 to 10).
class PreviewController extends ChangeNotifier implements ProgressView {
  PreviewController(this.content)
    : _roomId = content.story.startRoomId,
      _visited = {content.story.startRoomId};

  final GameContent content;

  String _roomId;
  final Set<String> _visited;
  bool _revealAll = false;

  /// The room currently shown.
  String get currentRoomId => _roomId;
  RoomDef get currentRoom => content.roomById(_roomId)!;

  /// Review mode: show every room, item, person and clue, and allow viewing any
  /// object. Used to review art and writing. Not a gameplay feature.
  bool get revealAll => _revealAll;

  set revealAll(bool value) {
    if (value == _revealAll) return;
    _revealAll = value;
    notifyListeners();
  }

  /// Starting inventory, or everything in review mode.
  List<String> get inventory => _revealAll
      ? content.items.map((i) => i.id).toList()
      : List.unmodifiable(content.story.startItems);

  /// Voices the player already knows. At the start only Wren, who wrote the
  /// letter, is known.
  Set<String> get knownCharacterIds => _revealAll
      ? content.story.characters.map((c) => c.id).toSet()
      : const {'wren'};

  bool isVisited(String roomId) => _revealAll || _visited.contains(roomId);

  /// Whether the exit can be used right now.
  bool canUseExit(ExitDef exit) => _revealAll || exit.initiallyOpen;

  /// Whether the player may look at and use this object.
  bool canInteract(HotspotDef hotspot) =>
      _revealAll || (hotspot.requires?.evaluate(this) ?? true);

  /// Moves the view to [roomId] if an open exit leads there (or in review mode).
  bool moveTo(String roomId) {
    if (roomId == _roomId) return true;
    final reachable =
        _revealAll ||
        currentRoom.exits.any((e) => e.toRoomId == roomId && e.initiallyOpen);
    if (!reachable) return false;
    _roomId = roomId;
    _visited.add(roomId);
    notifyListeners();
    return true;
  }

  /// Back to the start of the story.
  void restart() {
    _roomId = content.story.startRoomId;
    _visited
      ..clear()
      ..add(_roomId);
    notifyListeners();
  }

  // ProgressView: the start-of-game state. Nothing has been done yet.

  @override
  bool hasItem(String id) => inventory.contains(id);
  @override
  bool puzzleSolved(String id) => false;
  @override
  int flag(String id) => content.flagById(id)?.initial ?? 0;
  @override
  bool exitOpen(String id) => content.exitById(id)?.initiallyOpen ?? false;
  @override
  bool examined(String id) => false;
  @override
  bool choiceResolved(String id) => false;
  @override
  bool visitedRoom(String id) => _visited.contains(id);
}
