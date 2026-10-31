import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/content/definitions/puzzle_def.dart';
import 'package:hauntquest/domain/puzzles/puzzle_evaluator.dart';

import '../content/content_fixture.dart';

void main() {
  final content = contentFrom(freshRaw());
  PuzzleDef puzzle(String id) => content.puzzleById(id)!;

  test('sequence: correct, partial prefix, incorrect', () {
    final p = puzzle('p1_candle_moons');
    expect(
      evaluatePuzzle(
        p,
        const SequenceInput(['crescent', 'half', 'full', 'waning']),
      ),
      Verdict.correct,
    );
    expect(
      evaluatePuzzle(p, const SequenceInput(['crescent', 'half'])),
      Verdict.partial,
    );
    expect(
      evaluatePuzzle(
        p,
        const SequenceInput(['half', 'crescent', 'full', 'waning']),
      ),
      Verdict.incorrect,
    );
    expect(evaluatePuzzle(p, const SequenceInput([])), Verdict.incorrect);
  });

  test('sequence P9 ignores the decoy only when the order is exact', () {
    final p = puzzle('p9_resonance_engine');
    expect(
      evaluatePuzzle(p, const SequenceInput(['tide', 'ember', 'gale'])),
      Verdict.correct,
    );
    expect(
      evaluatePuzzle(p, const SequenceInput(['tide', 'ember', 'stone'])),
      Verdict.incorrect,
    );
  });

  test('cipher: normalizes case and spaces, scores near misses', () {
    final p = puzzle('p3_shelf_cipher');
    expect(evaluatePuzzle(p, const CipherInput('listen')), Verdict.correct);
    expect(evaluatePuzzle(p, const CipherInput(' Li sten ')), Verdict.correct);
    expect(evaluatePuzzle(p, const CipherInput('LISTAN')), Verdict.partial);
    expect(evaluatePuzzle(p, const CipherInput('ZZZZZZ')), Verdict.incorrect);
    expect(evaluatePuzzle(p, const CipherInput('')), Verdict.incorrect);
  });

  test('dial: exact, within two notches, far', () {
    final p = puzzle('p5_resonance_tuner');
    expect(evaluatePuzzle(p, const DialInput(73)), Verdict.correct);
    expect(evaluatePuzzle(p, const DialInput(71)), Verdict.partial);
    expect(evaluatePuzzle(p, const DialInput(37)), Verdict.incorrect);
  });

  test('combine: all slots, some slots, none', () {
    final p = puzzle('p4_torn_pages');
    expect(
      evaluatePuzzle(
        p,
        const PlacedItemsInput({'torn_page_left', 'torn_page_right'}),
      ),
      Verdict.correct,
    );
    expect(
      evaluatePuzzle(p, const PlacedItemsInput({'torn_page_left'})),
      Verdict.partial,
    );
    expect(
      evaluatePuzzle(p, const PlacedItemsInput({'spare_cog'})),
      Verdict.incorrect,
    );
  });

  test('useItem: right and wrong item', () {
    final p = puzzle('p2_wake_tallow');
    expect(
      evaluatePuzzle(p, const UseItemInput('brass_winding_key')),
      Verdict.correct,
    );
    expect(
      evaluatePuzzle(p, const UseItemInput('spare_cog')),
      Verdict.incorrect,
    );
  });

  test('clock: exact, right hour wrong minute, wrong hour', () {
    final p = puzzle('p7_stopped_hands');
    expect(evaluatePuzzle(p, const ClockInput(11, 40)), Verdict.correct);
    expect(evaluatePuzzle(p, const ClockInput(11, 10)), Verdict.partial);
    expect(evaluatePuzzle(p, const ClockInput(3, 40)), Verdict.incorrect);
  });

  test('gears: exact, some right, none right', () {
    final p = puzzle('p8_gear_alignment');
    expect(evaluatePuzzle(p, const GearsInput([2, 0, 3])), Verdict.correct);
    expect(evaluatePuzzle(p, const GearsInput([2, 1, 1])), Verdict.partial);
    expect(evaluatePuzzle(p, const GearsInput([1, 1, 1])), Verdict.incorrect);
  });

  test('is deterministic', () {
    final p = puzzle('p3_shelf_cipher');
    final first = evaluatePuzzle(p, const CipherInput('LISTAN'));
    for (var i = 0; i < 20; i++) {
      expect(evaluatePuzzle(p, const CipherInput('LISTAN')), first);
    }
  });

  test('throws when input does not match the puzzle kind', () {
    expect(
      () =>
          evaluatePuzzle(puzzle('p5_resonance_tuner'), const CipherInput('73')),
      throwsArgumentError,
    );
  });

  test('every puzzle in the content is solvable by its own config', () {
    for (final p in content.puzzles) {
      final c = p.config;
      final PuzzleInput solved = switch (p.kind) {
        PuzzleKind.sequence => SequenceInput(
          (c['solution'] as List).cast<String>(),
        ),
        PuzzleKind.cipher => CipherInput(c['answer'] as String),
        PuzzleKind.dial => DialInput(c['target'] as int),
        PuzzleKind.combine => PlacedItemsInput(
          (c['slots'] as List).cast<String>().toSet(),
        ),
        PuzzleKind.useItem => UseItemInput(c['itemId'] as String),
        PuzzleKind.clock => ClockInput(c['hour'] as int, c['minute'] as int),
        PuzzleKind.gears => GearsInput((c['target'] as List).cast<int>()),
      };
      expect(evaluatePuzzle(p, solved), Verdict.correct, reason: p.id);
    }
  });
}
