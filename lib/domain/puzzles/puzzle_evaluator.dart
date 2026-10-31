import '../../content/definitions/puzzle_def.dart';

/// Result of checking a puzzle attempt.
enum Verdict { correct, partial, incorrect }

/// What the player entered, per puzzle kind.
sealed class PuzzleInput {
  const PuzzleInput();
}

/// Ordered picks for a [PuzzleKind.sequence] puzzle.
final class SequenceInput extends PuzzleInput {
  const SequenceInput(this.picks);
  final List<String> picks;
}

/// Typed text for a [PuzzleKind.cipher] puzzle.
final class CipherInput extends PuzzleInput {
  const CipherInput(this.text);
  final String text;
}

/// Dial value for a [PuzzleKind.dial] puzzle.
final class DialInput extends PuzzleInput {
  const DialInput(this.value);
  final int value;
}

/// Items laid out for a [PuzzleKind.combine] puzzle.
final class PlacedItemsInput extends PuzzleInput {
  const PlacedItemsInput(this.itemIds);
  final Set<String> itemIds;
}

/// The item applied for a [PuzzleKind.useItem] puzzle.
final class UseItemInput extends PuzzleInput {
  const UseItemInput(this.itemId);
  final String itemId;
}

/// Hour (1 to 12) and minute for a [PuzzleKind.clock] puzzle.
final class ClockInput extends PuzzleInput {
  const ClockInput(this.hour, this.minute);
  final int hour;
  final int minute;
}

/// Notch position of each gear for a [PuzzleKind.gears] puzzle.
final class GearsInput extends PuzzleInput {
  const GearsInput(this.positions);
  final List<int> positions;
}

/// Pure, deterministic puzzle check. Reads the solution from `def.config` and
/// never uses randomness or time. Throws [ArgumentError] if [input] does not
/// match the puzzle kind, so wiring mistakes are loud.
Verdict evaluatePuzzle(PuzzleDef def, PuzzleInput input) {
  final c = def.config;
  switch ((def.kind, input)) {
    case (PuzzleKind.sequence, SequenceInput(:final picks)):
      final solution = (c['solution'] as List).cast<String>();
      if (_listEquals(picks, solution)) return Verdict.correct;
      final isPrefix =
          picks.isNotEmpty &&
          picks.length < solution.length &&
          _listEquals(picks, solution.sublist(0, picks.length));
      return isPrefix ? Verdict.partial : Verdict.incorrect;

    case (PuzzleKind.cipher, CipherInput(:final text)):
      final answer = (c['answer'] as String).toUpperCase();
      final typed = text.toUpperCase().replaceAll(RegExp(r'\s'), '');
      if (typed == answer) return Verdict.correct;
      if (typed.length == answer.length) {
        var same = 0;
        for (var i = 0; i < answer.length; i++) {
          if (typed[i] == answer[i]) same++;
        }
        if (same * 2 >= answer.length) return Verdict.partial;
      }
      return Verdict.incorrect;

    case (PuzzleKind.dial, DialInput(:final value)):
      final target = c['target'] as int;
      if (value == target) return Verdict.correct;
      return (value - target).abs() <= 2 ? Verdict.partial : Verdict.incorrect;

    case (PuzzleKind.combine, PlacedItemsInput(:final itemIds)):
      final slots = (c['slots'] as List).cast<String>();
      if (slots.every(itemIds.contains)) return Verdict.correct;
      return slots.any(itemIds.contains) ? Verdict.partial : Verdict.incorrect;

    case (PuzzleKind.useItem, UseItemInput(:final itemId)):
      return itemId == c['itemId'] ? Verdict.correct : Verdict.incorrect;

    case (PuzzleKind.clock, ClockInput(:final hour, :final minute)):
      final sameHour = hour % 12 == (c['hour'] as int) % 12;
      if (sameHour && minute == c['minute']) return Verdict.correct;
      return sameHour ? Verdict.partial : Verdict.incorrect;

    case (PuzzleKind.gears, GearsInput(:final positions)):
      final target = (c['target'] as List).cast<int>();
      if (_listEquals(positions, target)) return Verdict.correct;
      var matches = 0;
      for (var i = 0; i < target.length && i < positions.length; i++) {
        if (positions[i] == target[i]) matches++;
      }
      return matches > 0 ? Verdict.partial : Verdict.incorrect;

    default:
      throw ArgumentError(
        'Input ${input.runtimeType} does not match puzzle kind ${def.kind.name} '
        'for puzzle "${def.id}".',
      );
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
