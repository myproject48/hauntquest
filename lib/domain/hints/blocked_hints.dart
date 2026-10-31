import '../../content/definitions/condition.dart';
import '../../content/definitions/effect.dart';
import '../../content/definitions/puzzle_def.dart';
import '../../content/definitions/room_def.dart';
import '../../content/game_content.dart';
import '../models/game_state.dart';

/// Builds gentle nudges for blocked actions: where to look, never what to do.
///
/// Pure and deterministic: the same content and state give the same text.
class BlockedHints {
  const BlockedHints(this.content);

  final GameContent content;

  /// Why a passage is closed, pointing toward what opens it.
  String exit(ExitDef exit, GameState state) {
    final opener = _puzzleOpening(exit.id);
    if (opener == null) {
      return 'Something elsewhere in the manor controls this way.';
    }
    final hotspot = content.hotspotById(opener.hotspotId);
    if (opener.roomId == state.currentRoomId && hotspot != null) {
      return 'Something in this room seems connected to it: the ${hotspot.label.toLowerCase()}.';
    }
    return 'Whatever opens it lies elsewhere in the manor.';
  }

  /// Why an object cannot be used yet.
  String hotspot(HotspotDef hotspot, GameState state) {
    final unmet = _firstUnmet(hotspot.requires, state);
    return unmet == null ? 'Not yet.' : _explain(unmet, state);
  }

  /// Why a puzzle cannot be attempted yet.
  String puzzle(PuzzleDef puzzle, GameState state) {
    final hotspot = content.hotspotById(puzzle.hotspotId);
    final unmet =
        _firstUnmet(hotspot?.requires, state) ??
        _firstUnmet(puzzle.unlockWhen, state);
    if (unmet != null) return _explain(unmet, state);
    final missing = puzzle.requiresItems.where((i) => !state.hasItem(i));
    if (missing.isNotEmpty) return _explain(HasItem(missing.first), state);
    return 'Not yet.';
  }

  // ------------------------------------------------------------- internals

  PuzzleDef? _puzzleOpening(String exitId) {
    for (final p in content.puzzles) {
      if (p.onSolved.any((e) => e is OpenExit && e.id == exitId)) return p;
    }
    return null;
  }

  /// The first leaf condition that is not met, depth first.
  Condition? _firstUnmet(Condition? c, GameState s) {
    if (c == null || c.evaluate(s)) return null;
    return switch (c) {
      All(:final items) =>
        items
            .map((i) => _firstUnmet(i, s))
            .firstWhere((u) => u != null, orElse: () => c),
      Any(:final items) => _firstUnmet(items.first, s) ?? c,
      _ => c,
    };
  }

  String _explain(Condition c, GameState s) {
    switch (c) {
      case HasItem(:final id):
        if (s.wasAcquired(id)) return 'You no longer carry what this needs.';
        final where = _roomWhereItemIsFound(id);
        if (where != null && s.visitedRoom(where.id)) {
          return 'You need something you have not found yet. Look around the ${where.name}.';
        }
        return 'You need something you have not found yet.';
      case PuzzleSolved(:final id):
        final p = content.puzzleById(id);
        final h = p == null ? null : content.hotspotById(p.hotspotId);
        if (p != null && h != null && p.roomId == s.currentRoomId) {
          return 'Something else here must be dealt with first: the ${h.label.toLowerCase()}.';
        }
        return 'Something elsewhere in the manor must be dealt with first.';
      case FlagAtLeast(:final id) || FlagEquals(:final id):
        final source = _hotspotSettingFlag(id);
        if (source != null && source.roomId == s.currentRoomId) {
          return 'Try using something you carry on the ${source.label.toLowerCase()}.';
        }
        return 'Something else has to happen first.';
      case Examined(:final id):
        final h = content.hotspotById(id);
        return h == null
            ? 'Look around more closely first.'
            : 'Take a closer look at the ${h.label.toLowerCase()} first.';
      default:
        return 'Something else has to happen first.';
    }
  }

  RoomDef? _roomWhereItemIsFound(String itemId) {
    for (final h in content.allHotspots) {
      final gives =
          h.onExamine.any((e) => e is GiveItem && e.id == itemId) ||
          h.useRules.any(
            (r) => r.effects.any((e) => e is GiveItem && e.id == itemId),
          );
      if (gives) return content.roomById(h.roomId);
    }
    for (final p in content.puzzles) {
      if (p.onSolved.any((e) => e is GiveItem && e.id == itemId)) {
        return content.roomById(p.roomId);
      }
    }
    return null;
  }

  HotspotDef? _hotspotSettingFlag(String flagId) {
    bool sets(Effect e) =>
        (e is SetFlag && e.id == flagId) || (e is AddFlag && e.id == flagId);
    for (final h in content.allHotspots) {
      if (h.useRules.any((r) => r.effects.any(sets))) return h;
    }
    return null;
  }
}
