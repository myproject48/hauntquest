import '../../content/definitions/puzzle_def.dart';
import 'puzzle_evaluator.dart';

/// A serializable draft. Saving a draft never checks it or grants a reward.
class PuzzleProgress {
  PuzzleProgress({required this.input, this.hintTier = 0});
  final PuzzleInput input;
  final int hintTier;

  Map<String, Object?> toJson() => {
    'hintTier': hintTier,
    'input': switch (input) {
      SequenceInput(:final picks) => {'type': 'sequence', 'value': picks},
      CipherInput(:final text) => {'type': 'cipher', 'value': text},
      DialInput(:final value) => {'type': 'dial', 'value': value},
      PlacedItemsInput(:final itemIds) => {
        'type': 'combine',
        'value': itemIds.toList(),
      },
      UseItemInput(:final itemId) => {'type': 'useItem', 'value': itemId},
      ClockInput(:final hour, :final minute) => {
        'type': 'clock',
        'value': [hour, minute],
      },
      GearsInput(:final positions) => {'type': 'gears', 'value': positions},
    },
  };

  factory PuzzleProgress.fromJson(Map<String, Object?> json) {
    final data = (json['input'] as Map).cast<String, Object?>();
    final value = data['value'];
    final input = switch (data['type']) {
      'sequence' => SequenceInput(
        List.unmodifiable((value as List).cast<String>()),
      ),
      'cipher' => CipherInput(value as String),
      'dial' => DialInput(value as int),
      'combine' => PlacedItemsInput(
        Set.unmodifiable((value as List).cast<String>()),
      ),
      'useItem' => UseItemInput(value as String),
      'clock' => ClockInput((value as List)[0] as int, value[1] as int),
      'gears' => GearsInput(List.unmodifiable((value as List).cast<int>())),
      _ => throw const FormatException('Unknown puzzle draft input'),
    };
    return PuzzleProgress(
      input: input,
      hintTier: (json['hintTier'] as int? ?? 0).clamp(0, 3),
    );
  }
}

/// Enforces the legal input domain independently of the Flutter controls.
bool isLegalPuzzleInput(PuzzleDef def, PuzzleInput input) {
  final c = def.config;
  return switch ((def.kind, input)) {
    (PuzzleKind.sequence, SequenceInput(:final picks)) =>
      picks.length <= (c['solution'] as List).length &&
          picks.toSet().length == picks.length &&
          picks.every((c['options'] as List).contains),
    (PuzzleKind.cipher, CipherInput(:final text)) => text.length <= 200,
    (PuzzleKind.dial, DialInput(:final value)) =>
      value >= (c['min'] as int) && value <= (c['max'] as int),
    (PuzzleKind.combine, PlacedItemsInput(:final itemIds)) =>
      itemIds.length <= (c['slots'] as List).length,
    (PuzzleKind.useItem, UseItemInput()) => true,
    (PuzzleKind.clock, ClockInput(:final hour, :final minute)) =>
      hour >= 1 && hour <= 12 && minute >= 0 && minute < 60,
    (PuzzleKind.gears, GearsInput(:final positions)) =>
      positions.length == (c['target'] as List).length &&
          positions.every((p) => p >= 0 && p < (c['positions'] as int)),
    _ => false,
  };
}

/// Starting input for a puzzle, taken from its content definition.
PuzzleInput initialInputFor(PuzzleDef def) {
  final c = def.config;
  return switch (def.kind) {
    PuzzleKind.sequence => const SequenceInput([]),
    PuzzleKind.cipher => const CipherInput(''),
    PuzzleKind.dial => DialInput(c['start'] as int),
    PuzzleKind.combine => const PlacedItemsInput({}),
    PuzzleKind.useItem => const UseItemInput(''),
    PuzzleKind.clock => const ClockInput(12, 0),
    PuzzleKind.gears => GearsInput(
      List.filled((c['target'] as List).length, 0),
    ),
  };
}
