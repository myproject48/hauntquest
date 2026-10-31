import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/game_controller.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/content/definitions/puzzle_def.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/engine/game_events.dart';
import 'package:hauntquest/domain/models/game_state.dart';
import 'package:hauntquest/domain/puzzles/puzzle_evaluator.dart';
import 'package:hauntquest/domain/puzzles/puzzle_progress.dart';

import '../content/content_fixture.dart';

PuzzleInput solutionFor(PuzzleDef p) {
  final c = p.config;
  return switch (p.kind) {
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
}

PuzzleInput wrongFor(PuzzleDef p) => switch (p.kind) {
  PuzzleKind.sequence => const SequenceInput([]),
  PuzzleKind.cipher => const CipherInput('WRONG'),
  PuzzleKind.dial => DialInput(p.config['start'] as int),
  PuzzleKind.combine => const PlacedItemsInput({}),
  PuzzleKind.useItem => const UseItemInput('wrens_letter'),
  PuzzleKind.clock => const ClockInput(12, 0),
  PuzzleKind.gears => GearsInput(
    List.filled((p.config['target'] as List).length, 0),
  ),
};

Iterable<List<T>> permutations<T>(List<T> values, int length) sync* {
  if (length == 0) {
    yield [];
    return;
  }
  for (final value in values) {
    for (final rest in permutations(
      values.where((v) => v != value).toList(),
      length - 1,
    )) {
      yield [value, ...rest];
    }
  }
}

void main() {
  final content = contentFrom(freshRaw());
  final engine = GameEngine(content);
  GameState ready(PuzzleDef p) => engine.newGame().copyWith(
    currentRoomId: p.roomId,
    inventory: content.items.map((i) => i.id).toList(),
    acquiredItemIds: content.items.map((i) => i.id).toSet(),
    solvedPuzzleIds: content.puzzles
        .where((other) => other.id != p.id)
        .map((other) => other.id)
        .toSet(),
    flags: {
      for (final f in content.story.flags)
        f.id: f.id.endsWith('_revealed') ? 0 : f.max,
    },
  );

  for (final p in content.puzzles) {
    group(p.id, () {
      test(
        'explicit correct input completes, consumes and rewards exactly once',
        () {
          final s = ready(p);
          expect(engine.puzzleAccess(s, p), PuzzleAccess.available);
          final r = engine.submitPuzzle(s, p.id, solutionFor(p));
          expect(r.ok, isTrue);
          expect(r.state.puzzleSolved(p.id), isTrue);
          expect(r.events.whereType<PuzzleSolved>(), hasLength(1));
          expect(r.message, p.successText);
          for (final id in p.consumesItems) {
            expect(r.state.hasItem(id), isFalse);
          }
          final repeat = engine.submitPuzzle(r.state, p.id, solutionFor(p));
          expect(repeat.ok, isFalse);
          expect(repeat.state, r.state);
          expect(repeat.itemsAcquired, isEmpty);
          expect(repeat.events.whereType<PuzzleSolved>(), isEmpty);
        },
      );
      test(
        'incorrect input gives feedback without changing rewards or inventory',
        () {
          final s = ready(p);
          final r = engine.submitPuzzle(s, p.id, wrongFor(p));
          expect(r.state.puzzleSolved(p.id), isFalse);
          expect(r.state.puzzleAttempts[p.id], 1);
          expect(r.message, isNotEmpty);
          expect(r.state.inventory, s.inventory);
          expect(r.state.flags, s.flags);
          expect(r.state.openExitIds, s.openExitIds);
        },
      );
      test(
        'draft and all hint tiers survive JSON and controller restart',
        () async {
          final store = MemoryGameStore();
          final game = GameController(content, initial: ready(p), store: store);
          for (var tier = 1; tier <= 3; tier++) {
            final r = game.savePuzzleProgress(p.id, solutionFor(p), tier);
            expect(r.ok, isTrue);
            expect(
              game.state.puzzleSolved(p.id),
              isFalse,
              reason: 'Editing must never solve a puzzle',
            );
            expect(game.state.puzzleAttempts[p.id], isNull);
            await game.flushSaves();
            final restored = GameState.fromJson(
              jsonDecode(jsonEncode(store.savedState!.toJson()))
                  as Map<String, Object?>,
            );
            final reopened = GameController(content, initial: restored);
            expect(reopened.state.puzzleProgress[p.id]!.hintTier, tier);
            expect(
              evaluatePuzzle(p, reopened.state.puzzleProgress[p.id]!.input),
              Verdict.correct,
            );
            reopened.dispose();
          }
          game.submitPuzzle(p.id, solutionFor(p));
          final restored = GameState.fromJson(
            jsonDecode(jsonEncode(game.state.toJson())) as Map<String, Object?>,
          );
          expect(engine.puzzleAccess(restored, p), PuzzleAccess.solved);
          expect(
            engine.savePuzzleProgress(restored, p.id, wrongFor(p), 0).ok,
            isFalse,
          );
          game.dispose();
        },
      );
      test('room, story and inventory prerequisites cannot be bypassed', () {
        final s = ready(p);
        final elsewhere = s.copyWith(
          currentRoomId: content.rooms.firstWhere((r) => r.id != p.roomId).id,
        );
        expect(
          engine.submitPuzzle(elsewhere, p.id, solutionFor(p)).state,
          elsewhere,
        );
        for (final item in p.requiresItems) {
          final missing = s.copyWith(inventory: [...s.inventory]..remove(item));
          expect(
            engine
                .submitPuzzle(missing, p.id, solutionFor(p))
                .state
                .puzzleSolved(p.id),
            isFalse,
          );
        }
        if (p.unlockWhen != null) {
          final locked = s.copyWith(solvedPuzzleIds: {}, flags: {});
          expect(
            engine.submitPuzzle(locked, p.id, solutionFor(p)).state,
            locked,
          );
        }
      });
    });
  }

  test(
    'exhaustive ordered inputs have exactly one solution per sequence puzzle',
    () {
      for (final p in content.puzzles.where(
        (p) => p.kind == PuzzleKind.sequence,
      )) {
        final candidates = permutations(
          (p.config['options'] as List).cast<String>(),
          (p.config['solution'] as List).length,
        );
        expect(
          candidates.where(
            (v) => evaluatePuzzle(p, SequenceInput(v)) == Verdict.correct,
          ),
          hasLength(1),
          reason: p.id,
        );
      }
    },
  );

  test('exhaustive disc, mirror, clock and dial domains each have exactly one solution', () {
    for (final p in content.puzzles) {
      final c = p.config;
      Iterable<PuzzleInput> candidates() sync* {
        if (p.kind == PuzzleKind.gears) {
          final base = c['positions'] as int;
          final length = (c['target'] as List).length;
          for (var code = 0; code < pow(base, length); code++) {
            var rest = code;
            yield GearsInput(
              List.generate(length, (_) {
                final digit = rest % base;
                rest ~/= base;
                return digit;
              }),
            );
          }
        } else if (p.kind == PuzzleKind.clock) {
          for (var h = 1; h <= 12; h++) {
            for (var m = 0; m < 60; m++) {
              yield ClockInput(h, m);
            }
          }
        } else if (p.kind == PuzzleKind.dial) {
          for (var n = c['min'] as int; n <= (c['max'] as int); n++) {
            yield DialInput(n);
          }
        }
      }

      if ([
        PuzzleKind.gears,
        PuzzleKind.clock,
        PuzzleKind.dial,
      ].contains(p.kind)) {
        expect(
          candidates().where((v) => evaluatePuzzle(p, v) == Verdict.correct),
          hasLength(1),
          reason: p.id,
        );
      }
    }
  });

  test('seeded randomized edits, resets, saves and submissions preserve state invariants', () {
    final random = Random(4816);
    for (final p in content.puzzles) {
      var s = ready(p);
      for (var i = 0; i < 150; i++) {
        final input = random.nextBool() ? solutionFor(p) : wrongFor(p);
        final before = s;
        final r = random.nextInt(3) == 0
            ? engine.submitPuzzle(s, p.id, input)
            : engine.savePuzzleProgress(s, p.id, input, random.nextInt(4));
        s = GameState.fromJson(
          jsonDecode(jsonEncode(r.state.toJson())) as Map<String, Object?>,
        );
        expect(s.inventory.toSet().length, s.inventory.length);
        expect(s.acquiredItemIds.containsAll(before.acquiredItemIds), isTrue);
        expect(s.solvedPuzzleIds.containsAll(before.solvedPuzzleIds), isTrue);
        if (before.puzzleSolved(p.id)) {
          expect(s, before);
        }
      }
    }
  });

  test('invalid clock aliases, extra ingredients and malformed discs never complete', () {
    final clock = content.puzzleById('p7_stopped_hands')!;
    expect(evaluatePuzzle(clock, const ClockInput(23, 40)), Verdict.incorrect);
    final pages = content.puzzleById('p4_torn_pages')!;
    expect(
      evaluatePuzzle(
        pages,
        const PlacedItemsInput({
          'torn_page_left',
          'torn_page_right',
          'wrens_letter',
        }),
      ),
      isNot(Verdict.correct),
    );
    final mirror = content.puzzleById('p14_mirror')!;
    expect(isLegalPuzzleInput(mirror, const GearsInput([1])), isFalse);
    expect(isLegalPuzzleInput(mirror, GearsInput(List.filled(9, 2))), isFalse);
  });

  test('every apparatus starts unsolved and resetting does not erase hints or attempts', () {
    for (final p in content.puzzles) {
      expect(
        evaluatePuzzle(p, initialInputFor(p)),
        isNot(Verdict.correct),
        reason: p.id,
      );
      var s = engine.submitPuzzle(ready(p), p.id, wrongFor(p)).state;
      s = engine.revealPuzzleHint(s, p.id).state;
      s = engine.savePuzzleProgress(s, p.id, initialInputFor(p), 1).state;
      expect(s.puzzleAttempts[p.id], 1);
      expect(s.puzzleProgress[p.id]!.hintTier, 1);
      expect(s.puzzleSolved(p.id), isFalse);
    }
  });

  test('missing prerequisites permit three persisted hints without changing apparatus rewards', () {
    final p = content.puzzleById('p14_mirror')!;
    var s = engine.newGame();
    for (var i = 1; i <= 3; i++) {
      final r = engine.revealPuzzleHint(s, p.id);
      expect(r.ok, isTrue);
      s = r.state;
      expect(s.puzzleProgress[p.id]!.hintTier, i);
      expect(s.puzzleSolved(p.id), isFalse);
      expect(s.inventory, ['wrens_letter']);
    }
    expect(engine.revealPuzzleHint(s, p.id).state, s);
    expect(engine.submitPuzzle(s, p.id, solutionFor(p)).state, s);
    expect(engine.savePuzzleProgress(s, p.id, solutionFor(p), 3).state, s);
  });

  test(
    'all inventory combinations and item choices have one exact solution',
    () {
      final ids = content.items.map((i) => i.id).toList();
      for (final p in content.puzzles) {
        if (p.kind == PuzzleKind.combine) {
          var solutions = 0;
          for (var mask = 0; mask < (1 << ids.length); mask++) {
            final items = {
              for (var i = 0; i < ids.length; i++)
                if ((mask & (1 << i)) != 0) ids[i],
            };
            if (evaluatePuzzle(p, PlacedItemsInput(items)) == Verdict.correct) {
              solutions++;
            }
          }
          expect(solutions, 1);
        } else if (p.kind == PuzzleKind.useItem) {
          expect(
            ids.where(
              (id) => evaluatePuzzle(p, UseItemInput(id)) == Verdict.correct,
            ),
            hasLength(1),
          );
        }
      }
    },
  );

  test('all candidate symbol substitutions have one canonical word', () {
    final p = content.puzzleById('p10_symbol_seal')!;
    final letters = (p.config['substitution'] as Map).values
        .cast<String>()
        .toList();
    final length = (p.config['answer'] as String).length;
    var solutions = 0;
    for (var code = 0; code < pow(letters.length, length); code++) {
      var rest = code;
      final word = List.generate(length, (_) {
        final letter = letters[rest % letters.length];
        rest ~/= letters.length;
        return letter;
      }).join();
      if (evaluatePuzzle(p, CipherInput(word)) == Verdict.correct) solutions++;
    }
    expect(solutions, 1);
  });

  test('legacy saves load with no drafts', () {
    final json = engine.newGame().toJson()..remove('puzzleProgress');
    expect(GameState.fromJson(json).puzzleProgress, isEmpty);
  });
}
