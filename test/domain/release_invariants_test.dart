// Release-readiness checks for the pure game domain: unexpected inputs never
// crash or change state, and long random play keeps every state invariant
// that the save system relies on.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/persistence/save_codec.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/models/game_state.dart';
import 'package:hauntquest/domain/puzzles/puzzle_evaluator.dart';

import '../content/content_fixture.dart';
import 'complete_puzzle_system_test.dart' show solutionFor;
import 'narrative_fixture.dart';

void main() {
  final content = contentFrom(freshRaw());
  final engine = GameEngine(content);
  final codec = SaveCodec(content);

  /// Every unexpected action must be rejected with a message and leave the
  /// state untouched (no throw, no partial mutation).
  void expectRejected(GameState before, EngineResult r, String what) {
    expect(r.ok, isFalse, reason: '$what should be rejected');
    expect(r.rejection, isNotNull, reason: what);
    expect(r.rejection!.message, isNotEmpty, reason: what);
    expect(r.state, before, reason: '$what must not change state');
  }

  group('invalid and unexpected inputs', () {
    final s = engine.newGame();

    test('unknown ids are rejected, never thrown', () {
      final cases = <String, EngineResult Function()>{
        'move to unknown exit': () => engine.move(s, 'no_such_exit'),
        'travel to unknown room': () => engine.travelTo(s, 'no_such_room'),
        'examine unknown hotspot': () => engine.examine(s, 'no_such_hotspot'),
        'inspect unknown item': () => engine.inspectItem(s, 'no_such_item'),
        'acquire unknown item': () => engine.acquireItem(s, 'no_such_item'),
        'combine unknown items': () =>
            engine.combineItems(s, 'no_such_item', 'wrens_letter'),
        'use unknown item': () => engine.useItem(s, 'no_such_item', 'h_tallow'),
        'use on unknown hotspot': () =>
            engine.useItem(s, 'wrens_letter', 'no_such_hotspot'),
        'submit unknown puzzle': () =>
            engine.submitPuzzle(s, 'no_such_puzzle', const CipherInput('x')),
        'hint for unknown puzzle': () =>
            engine.revealPuzzleHint(s, 'no_such_puzzle'),
        'draft for unknown puzzle': () => engine.savePuzzleProgress(
          s,
          'no_such_puzzle',
          const CipherInput('x'),
          0,
        ),
        'unknown choice': () => engine.resolveChoice(s, 'no_such_choice', 'x'),
        'unknown option': () =>
            engine.resolveChoice(s, 'c_tallow_welcome', 'no_such_option'),
        'empty ids': () => engine.move(s, ''),
      };
      for (final MapEntry(key: what, value: run) in cases.entries) {
        late EngineResult r;
        expect(() => r = run(), returnsNormally, reason: what);
        expectRejected(s, r, what);
      }
    });

    test('items the player does not hold cannot be used or combined', () {
      final notHeld = content.items
          .map((i) => i.id)
          .firstWhere((id) => !s.hasItem(id));
      expectRejected(s, engine.useItem(s, notHeld, 'h_tallow'), 'use $notHeld');
      expectRejected(
        s,
        engine.combineItems(s, notHeld, 'wrens_letter'),
        'combine $notHeld',
      );
      expectRejected(
        s,
        engine.combineItems(s, 'wrens_letter', 'wrens_letter'),
        'combine an item with itself',
      );
    });

    test('a puzzle given the wrong kind of input is rejected, not thrown', () {
      // Make P1 reachable, then send it every input kind except its own.
      final ready = engine.examine(s, 'h_portrait').state;
      const wrongKinds = <PuzzleInput>[
        CipherInput('moon'),
        DialInput(3),
        PlacedItemsInput({'wrens_letter'}),
        UseItemInput('wrens_letter'),
        ClockInput(3, 15),
        GearsInput([1, 2, 3]),
      ];
      for (final input in wrongKinds) {
        late EngineResult r;
        expect(
          () => r = engine.submitPuzzle(ready, 'p1_candle_moons', input),
          returnsNormally,
          reason: '${input.runtimeType}',
        );
        expect(r.ok, isFalse, reason: '${input.runtimeType}');
        expect(r.state.puzzleSolved('p1_candle_moons'), isFalse);
      }
      for (final tier in [-1, 4, 99]) {
        expectRejected(
          ready,
          engine.savePuzzleProgress(
            ready,
            'p1_candle_moons',
            const SequenceInput(['crescent']),
            tier,
          ),
          'hint tier $tier',
        );
      }
    });

    test('puzzles in rooms the player has not reached cannot be solved', () {
      final vaultFinale = content.puzzleById('p9_resonance_engine')!;
      expectRejected(
        s,
        engine.submitPuzzle(s, vaultFinale.id, solutionFor(vaultFinale)),
        'remote puzzle',
      );
    });

    test('nothing changes the story after an ending', () {
      final atDecision = reachFinalDecision(content);
      final ended = engine
          .resolveChoice(atDecision, content.story.finalChoiceId, 'ef_release')
          .state;
      expect(ended.endingId, isNotNull);
      final attempts = <String, EngineResult>{
        'move': engine.move(ended, 'vault_to_clocktower'),
        'examine': engine.examine(ended, 'h_portrait'),
        'final choice again': engine.resolveChoice(
          ended,
          content.story.finalChoiceId,
          'ef_release',
        ),
      };
      for (final MapEntry(key: what, value: r) in attempts.entries) {
        expect(r.state.endingId, ended.endingId, reason: what);
        expect(r.state.flags, ended.flags, reason: what);
      }
    });
  });

  group('state invariants under random play', () {
    final exits = content.allExits.map((e) => e.id).toList();
    final hotspots = content.allHotspots.map((h) => h.id).toList();
    final items = content.items.map((i) => i.id).toList();
    final choices = content.choices;

    /// A random but legal-looking action. Most are rejected; the point is
    /// that no sequence can break the state.
    EngineResult randomAction(Random rng, GameState s) {
      T pick<T>(List<T> l) => l[rng.nextInt(l.length)];
      switch (rng.nextInt(7)) {
        case 0:
          return engine.move(s, pick(exits));
        case 1:
          return engine.examine(s, pick(hotspots));
        case 2:
          return engine.useItem(s, pick(items), pick(hotspots));
        case 3:
          return engine.combineItems(s, pick(items), pick(items));
        case 4:
          final p = pick(content.puzzles);
          // Half the time the real solution, otherwise a hint request.
          return rng.nextBool()
              ? engine.submitPuzzle(s, p.id, solutionFor(p))
              : engine.revealPuzzleHint(s, p.id);
        case 5:
          final c = pick(choices);
          return engine.resolveChoice(s, c.id, pick(c.options).id);
        default:
          return engine.inspectItem(s, pick(items));
      }
    }

    void checkInvariants(GameState prev, GameState s, String where) {
      expect(
        s.inventory.toSet().length,
        s.inventory.length,
        reason: '$where: duplicate item in inventory',
      );
      expect(
        s.acquiredItemIds.containsAll(s.inventory),
        isTrue,
        reason: '$where: holding an item never acquired',
      );
      expect(
        s.acquiredItemIds.containsAll(prev.acquiredItemIds),
        isTrue,
        reason: '$where: acquisition history shrank',
      );
      expect(
        s.solvedPuzzleIds.containsAll(prev.solvedPuzzleIds),
        isTrue,
        reason: '$where: a solved puzzle became unsolved',
      );
      expect(
        s.visitedRoomIds.contains(s.currentRoomId),
        isTrue,
        reason: '$where: current room not visited',
      );
      for (final f in s.flags.entries) {
        final def = content.flagById(f.key)!;
        expect(
          f.value,
          inInclusiveRange(def.min, def.max),
          reason: '$where: flag ${f.key} out of range',
        );
      }
      if (prev.endingId != null) {
        expect(s, prev, reason: '$where: state changed after the ending');
      }
    }

    for (final seed in [1, 7, 42, 2026, 31337]) {
      test('seed $seed: 600 random actions keep invariants and saves valid', () {
        final rng = Random(seed);
        var s = engine.newGame();
        for (var i = 0; i < 600; i++) {
          final r = randomAction(rng, s);
          if (!r.ok) {
            // A rejection leaves the state alone, except that a wrong try at
            // a puzzle counts one attempt (it drives hint escalation).
            final before = s.toJson(), after = r.state.toJson();
            final changed = [
              for (final k in after.keys)
                if ('${before[k]}' != '${after[k]}') k,
            ];
            expect(
              changed,
              anyOf(isEmpty, ['puzzleAttempts']),
              reason:
                  'step $i: rejected "${r.rejection?.message}" changed $changed',
            );
            if (changed.isNotEmpty) {
              final grew = [
                for (final e in r.state.puzzleAttempts.entries)
                  if (e.value != (s.puzzleAttempts[e.key] ?? 0))
                    e.value - (s.puzzleAttempts[e.key] ?? 0),
              ];
              expect(grew, [1], reason: 'step $i: one attempt at a time');
              s = r.state;
            }
            continue;
          }
          checkInvariants(s, r.state, 'seed $seed step $i');
          s = r.state;
          if (i % 25 == 0) {
            // The save codec runs the strict semantic validator.
            final restored = codec.decode(codec.encode(s));
            expect(
              restored.toJson(),
              codec.decode(codec.encode(restored)).toJson(),
            );
            expect(restored.currentRoomId, s.currentRoomId);
            expect(restored.inventory, s.inventory);
            expect(restored.flags, s.flags);
          }
        }
        final restored = codec.decode(codec.encode(s));
        expect(restored.solvedPuzzleIds, s.solvedPuzzleIds);
        expect(restored.resolvedChoices, s.resolvedChoices);
      });
    }

    test('items are never granted twice, even when re-examined', () {
      var s = engine.newGame();
      s = engine.examine(s, 'h_portrait').state;
      final once = s.inventory.length;
      for (var i = 0; i < 5; i++) {
        s = engine.examine(s, 'h_portrait').state;
      }
      expect(s.inventory.length, once);
      expect(s.inventory.where((id) => id == 'brass_winding_key').length, 1);
    });
  });

  group('narrative ending reachability', () {
    test('every branch reaches the final decision, release is always '
        'possible, and all three endings occur', () {
      List<String> options(String choiceId) =>
          content.choiceById(choiceId)!.options.map((o) => o.id).toList();
      final finalId = content.story.finalChoiceId;
      final endingsSeen = <String>{};
      var branches = 0;
      var blocked = 0;
      for (final welcome in options('c_tallow_welcome')) {
        for (final memory in options('c_tallow_memory')) {
          for (final whisper in options('c_echo_whisper')) {
            for (final identity in options('c_echo_identity')) {
              for (final bargain in options('c_maul_bargain')) {
                for (final terms in options('c_maul_terms')) {
                  for (final research in [true, false]) {
                    final path =
                        '$welcome/$memory/$whisper/$identity/$bargain/$terms/'
                        'research=$research';
                    final GameState s;
                    try {
                      s = reachFinalDecision(
                        content,
                        welcome: welcome,
                        memory: memory,
                        whisper: whisper,
                        identity: identity,
                        bargain: bargain,
                        terms: terms,
                        research: research,
                      );
                    } on StateError {
                      // An option that this path disables (for example a
                      // term that needs earlier research). The player picks
                      // another; it is not a dead end, checked below.
                      blocked++;
                      continue;
                    }
                    branches++;
                    final release = engine.resolveChoice(
                      s,
                      finalId,
                      'ef_release',
                    );
                    expect(release.ok, isTrue, reason: path);
                    expect(release.state.endingId, 'release_echo');
                    for (final o in options(finalId)) {
                      final r = engine.resolveChoice(s, finalId, o);
                      if (r.ok) endingsSeen.add(r.state.endingId!);
                    }
                  }
                }
              }
            }
          }
        }
      }
      expect(branches, greaterThan(100));
      // Disabled options must never make up the majority of paths.
      expect(blocked, lessThan(branches));
      expect(endingsSeen, {'release_echo', 'seal_echo', 'echo_guardian'});
    });
  });
}
