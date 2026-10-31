import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/engine/game_events.dart';
import 'package:hauntquest/domain/models/game_state.dart';
import 'package:hauntquest/domain/puzzles/puzzle_evaluator.dart';

import '../content/content_fixture.dart';
import 'complete_puzzle_system_test.dart' show solutionFor;

void main() {
  final content = contentFrom(freshRaw());
  final engine = GameEngine(content);

  /// Runs an action and fails the test if the engine rejected it.
  GameState ok(EngineResult r, [String what = '']) {
    expect(r.rejection, isNull, reason: '$what: ${r.rejection?.message}');
    return r.state;
  }

  // The opening moves of the Entrance Hall, reused by many tests.
  GameState openHall() {
    var s = engine.newGame();
    s = ok(engine.examine(s, 'h_portrait'), 'portrait');
    s = ok(
      engine.submitPuzzle(
        s,
        'p1_candle_moons',
        const SequenceInput(['crescent', 'half', 'full', 'waning']),
      ),
      'p1',
    );
    s = ok(engine.useItem(s, 'brass_winding_key', 'h_tallow'), 'wake Tallow');
    s = ok(engine.resolveChoice(s, 'c_tallow_welcome', 'tw_kind'), 'Tallow');
    s = ok(
      engine.resolveChoice(s, 'c_tallow_memory', 'tm_listen'),
      'Tallow memory',
    );
    return s;
  }

  group('new game', () {
    test('starts in the hall with the letter and declared flags', () {
      final s = engine.newGame();
      expect(s.currentRoomId, 'moonlit_hall');
      expect(s.visitedRoomIds, {'moonlit_hall'});
      expect(s.inventory, ['wrens_letter']);
      expect(s.flag('truthFragments'), 0);
      expect(s.endingId, isNull);
    });
  });

  group('room transitions and locked doors', () {
    test('a locked exit refuses with its text and a hint, state unchanged', () {
      final s = engine.newGame();
      final r = engine.move(s, 'hall_to_library');
      expect(r.rejection?.reason, RejectReason.exitLocked);
      expect(r.rejection?.message, contains('A seam in the wall holds fast'));
      expect(r.rejection?.hint, contains('candelabra'));
      expect(
        r.rejection?.hint,
        isNot(contains('crescent')),
        reason: 'hints never give the answer',
      );
      expect(r.state, same(s));
    });

    test('cannot use an exit from another room', () {
      final r = engine.move(engine.newGame(), 'workshop_to_library');
      expect(r.rejection?.reason, RejectReason.notHere);
    });

    test('solving the candle puzzle opens the library door', () {
      var s = engine.newGame();
      final solve = engine.submitPuzzle(
        s,
        'p1_candle_moons',
        const SequenceInput(['crescent', 'half', 'full', 'waning']),
      );
      expect(solve.exitsOpened, ['hall_to_library']);
      s = ok(solve);
      final move = engine.move(s, 'hall_to_library');
      expect(
        move.events.single,
        isA<RoomEntered>().having((e) => e.firstVisit, 'first', isTrue),
      );
      s = ok(move);
      expect(s.currentRoomId, 'forgotten_library');
      expect(
        s.visitedRoomIds,
        containsAll(['moonlit_hall', 'forgotten_library']),
      );
    });

    test('the way back is open, and revisiting is not a first visit', () {
      var s = openHall();
      s = ok(engine.move(s, 'hall_to_library'));
      s = ok(engine.move(s, 'library_to_hall'));
      final again = engine.move(s, 'hall_to_library');
      expect((again.events.single as RoomEntered).firstVisit, isFalse);
    });

    test('travelTo uses an open exit and refuses unreachable rooms', () {
      final s = engine.newGame();
      expect(
        engine.travelTo(s, 'forgotten_library').rejection?.reason,
        RejectReason.exitLocked,
      );
      expect(
        engine.travelTo(s, 'echo_vault').rejection?.reason,
        RejectReason.notHere,
      );
    });

    test('no room can be entered before its prerequisites', () {
      // Without solving anything, only the hall is reachable.
      var s = engine.newGame();
      for (final exit in content.allExits) {
        final r = engine.move(s, exit.id);
        if (exit.fromRoomId == s.currentRoomId) {
          expect(r.ok, exit.initiallyOpen, reason: exit.id);
        }
      }
      expect(s.visitedRoomIds, {'moonlit_hall'});
    });
  });

  group('examining and collecting', () {
    test(
      'first look grants the item once; repeat looks give the repeat text',
      () {
        var s = engine.newGame();
        final first = engine.examine(s, 'h_portrait');
        expect(first.itemsAcquired, ['brass_winding_key']);
        expect(first.message, contains('A brass key hangs'));
        s = ok(first);

        final again = engine.examine(s, 'h_portrait');
        expect(again.itemsAcquired, isEmpty);
        expect(again.message, contains('Listen twice'));
        expect(
          again.state.inventory.where((i) => i == 'brass_winding_key'),
          hasLength(1),
        );
      },
    );

    test('a consumed item is never granted again', () {
      var s = openHall();
      s = ok(engine.move(s, 'hall_to_library'));
      s = ok(
        engine.submitPuzzle(s, 'p3_shelf_cipher', const CipherInput('LISTEN')),
      );
      s = ok(engine.examine(s, 'l_hearth'));
      s = ok(
        engine.submitPuzzle(
          s,
          'p4_torn_pages',
          const PlacedItemsInput({'torn_page_left', 'torn_page_right'}),
        ),
      );
      expect(s.hasItem('torn_page_left'), isFalse);
      expect(
        s.consumedItemIds,
        containsAll(['torn_page_left', 'torn_page_right']),
      );
      // Looking at the hearth again does not return the page.
      s = ok(engine.examine(s, 'l_hearth'));
      expect(s.hasItem('torn_page_right'), isFalse);
    });

    test('a locked object explains itself and hints at what is needed', () {
      var s = engine.newGame();
      s = ok(
        engine.submitPuzzle(
          s,
          'p1_candle_moons',
          const SequenceInput(['crescent', 'half', 'full', 'waning']),
        ),
      );
      s = ok(engine.move(s, 'hall_to_library'));
      final r = engine.examine(s, 'l_desk');
      expect(r.rejection?.reason, RejectReason.hotspotLocked);
      expect(r.rejection?.message, contains('too dark'));
      expect(r.rejection?.hint, isNotNull);
      expect(r.state.hasItem('ottoline_journal'), isFalse);
    });

    test('cannot examine objects in other rooms', () {
      expect(
        engine.examine(engine.newGame(), 'l_desk').rejection?.reason,
        RejectReason.notHere,
      );
    });

    test('inspecting an item is recorded once', () {
      var s = engine.newGame();
      final r = engine.inspectItem(s, 'wrens_letter');
      expect(r.events.single, isA<ItemInspected>());
      s = r.state;
      expect(engine.inspectItem(s, 'wrens_letter').events, isEmpty);
      expect(
        engine.inspectItem(s, 'spare_cog').rejection?.reason,
        RejectReason.itemNotCarried,
      );
    });
  });

  group('using items', () {
    test(
      'the right item solves an item puzzle and starts the conversation',
      () {
        var s = engine.newGame();
        s = ok(engine.examine(s, 'h_portrait'));
        final r = engine.useItem(s, 'brass_winding_key', 'h_tallow');
        expect(
          r.events.whereType<PuzzleSolved>().single.puzzleId,
          'p2_wake_tallow',
        );
        expect(r.itemsAcquired, ['tallow_lantern']);
        expect(r.state.pendingChoiceIds, ['c_tallow_welcome']);
        // The key is not consumed by this puzzle.
        expect(r.state.hasItem('brass_winding_key'), isTrue);
      },
    );

    test('the wrong item counts an attempt and changes nothing else', () {
      final s = engine.newGame();
      final r = engine.useItem(s, 'wrens_letter', 'h_tallow');
      expect(r.rejection?.reason, RejectReason.itemDoesNothing);
      expect(r.state.puzzleAttempts['p2_wake_tallow'], 1);
      expect(r.state.solvedPuzzleIds, isEmpty);
    });

    test('an item without a rule does nothing', () {
      final r = engine.useItem(
        engine.newGame(),
        'wrens_letter',
        'h_front_door',
      );
      expect(r.rejection?.reason, RejectReason.itemDoesNothing);
    });

    test('a use rule applies once but can be replayed', () {
      var s = openHall();
      s = ok(engine.move(s, 'hall_to_library'));
      s = ok(engine.examine(s, 'l_desk'));
      s = ok(
        engine.submitPuzzle(s, 'p3_shelf_cipher', const CipherInput('LISTEN')),
      );
      s = ok(engine.examine(s, 'l_hearth'));
      s = ok(
        engine.submitPuzzle(
          s,
          'p4_torn_pages',
          const PlacedItemsInput({'torn_page_left', 'torn_page_right'}),
        ),
      );
      s = ok(engine.move(s, 'library_to_workshop'));
      s = ok(engine.useItem(s, 'silver_solvent', 'w_cabinet'));
      final truthBefore = s.flag('truthFragments');
      s = ok(engine.useItem(s, 'wax_cylinder', 'w_phonograph'));
      expect(s.flag('cylinderPlayed'), 1);
      expect(s.flag('truthFragments'), truthBefore + 1);
      final replay = engine.useItem(s, 'wax_cylinder', 'w_phonograph');
      expect(replay.message, contains('Seven, then three'));
      expect(
        replay.state.flag('truthFragments'),
        truthBefore + 1,
        reason: 'no double reward',
      );
    });
  });

  group('puzzles', () {
    test('wrong answers count attempts and never end the game', () {
      var s = engine.newGame();
      for (var i = 1; i <= 3; i++) {
        final r = engine.submitPuzzle(
          s,
          'p1_candle_moons',
          const SequenceInput(['waning', 'full', 'half', 'crescent']),
        );
        expect(r.ok, isTrue);
        expect(r.events.whereType<PuzzleSolved>(), isEmpty);
        s = r.state;
        expect(s.puzzleAttempts['p1_candle_moons'], i);
      }
    });

    test('a solved puzzle cannot be solved again', () {
      var s = engine.newGame();
      s = ok(
        engine.submitPuzzle(
          s,
          'p1_candle_moons',
          const SequenceInput(['crescent', 'half', 'full', 'waning']),
        ),
      );
      final again = engine.submitPuzzle(
        s,
        'p1_candle_moons',
        const SequenceInput(['crescent', 'half', 'full', 'waning']),
      );
      expect(again.rejection?.reason, RejectReason.puzzleSolved);
      expect(
        engine.puzzleAccess(s, content.puzzleById('p1_candle_moons')!),
        PuzzleAccess.solved,
      );
    });

    test('puzzles in other rooms or behind locks cannot be attempted', () {
      final s = engine.newGame();
      expect(
        engine
            .submitPuzzle(s, 'p3_shelf_cipher', const CipherInput('LISTEN'))
            .rejection
            ?.reason,
        RejectReason.puzzleUnavailable,
      );
    });

    test('a puzzle needing items reports what is missing', () {
      var s = openHall();
      s = ok(engine.move(s, 'hall_to_library'));
      final p4 = content.puzzleById('p4_torn_pages')!;
      expect(engine.puzzleAccess(s, p4), PuzzleAccess.missingItems);
      final r = engine.submitPuzzle(s, p4.id, const PlacedItemsInput({}));
      expect(r.rejection?.reason, RejectReason.puzzleMissingItems);
      expect(r.rejection?.hint, isNotNull);
    });
  });

  group('conversations', () {
    test('a choice is resolved once and its effects stick', () {
      var s = engine.newGame();
      s = ok(engine.examine(s, 'h_portrait'));
      s = ok(engine.useItem(s, 'brass_winding_key', 'h_tallow'));
      s = ok(engine.resolveChoice(s, 'c_tallow_welcome', 'tw_ask'));
      expect(s.flag('truthFragments'), 1);
      expect(s.resolvedChoices['c_tallow_welcome'], 'tw_ask');
      expect(s.pendingChoiceIds, ['c_tallow_memory']);
      expect(
        engine
            .resolveChoice(s, 'c_tallow_welcome', 'tw_kind')
            .rejection
            ?.reason,
        RejectReason.choiceUnavailable,
      );
    });

    test('a conversation cannot start from another room', () {
      expect(
        engine
            .resolveChoice(engine.newGame(), 'c_echo_whisper', 'ew_gentle')
            .rejection
            ?.reason,
        RejectReason.choiceUnavailable,
      );
    });
  });

  group('state', () {
    test('serializes and restores exactly', () {
      var s = openHall();
      s = ok(engine.move(s, 'hall_to_library'));
      s = ok(engine.examine(s, 'l_desk'));
      final restored = GameState.fromJson(s.toJson());
      expect(restored, s);
      expect(restored.inventory, s.inventory, reason: 'order matters');
    });

    test('state is immutable', () {
      final s = engine.newGame();
      expect(() => (s.inventory as List).add('x'), throwsUnsupportedError);
      expect(() => (s.flags as Map)['x'] = 1, throwsUnsupportedError);
    });
  });

  group('full playthroughs reach every ending', () {
    GameState playTo(String bargainOption, String? finalOption) {
      var s = openHall();
      for (final id in ['p10_symbol_seal', 'p14_mirror']) {
        s = ok(
          engine.submitPuzzle(s, id, solutionFor(content.puzzleById(id)!)),
        );
      }
      s = ok(engine.move(s, 'hall_to_library'));
      s = ok(engine.examine(s, 'l_desk'));
      s = ok(
        engine.submitPuzzle(s, 'p3_shelf_cipher', const CipherInput('LISTEN')),
      );
      for (final id in ['p12_rune_gaps', 'p15_evidence']) {
        s = ok(
          engine.submitPuzzle(s, id, solutionFor(content.puzzleById(id)!)),
        );
      }
      s = ok(engine.examine(s, 'l_hearth'));
      s = ok(
        engine.submitPuzzle(
          s,
          'p4_torn_pages',
          const PlacedItemsInput({'torn_page_left', 'torn_page_right'}),
        ),
      );
      s = ok(engine.examine(s, 'l_ledger'));
      s = ok(engine.move(s, 'library_to_workshop'));
      s = ok(engine.useItem(s, 'silver_solvent', 'w_cabinet'));
      s = ok(
        engine.submitPuzzle(
          s,
          'p13_alchemy',
          solutionFor(content.puzzleById('p13_alchemy')!),
        ),
      );
      s = ok(engine.useItem(s, 'wax_cylinder', 'w_phonograph'));
      s = ok(engine.submitPuzzle(s, 'p5_resonance_tuner', const DialInput(73)));
      s = ok(engine.resolveChoice(s, 'c_echo_whisper', 'ew_gentle'));
      s = ok(engine.resolveChoice(s, 'c_echo_identity', 'ei_person'));
      s = ok(engine.move(s, 'workshop_to_clocktower'));
      s = ok(
        engine.submitPuzzle(s, 'p7_stopped_hands', const ClockInput(11, 40)),
      );
      s = ok(
        engine.submitPuzzle(
          s,
          'p11_constellation',
          solutionFor(content.puzzleById('p11_constellation')!),
        ),
      );
      s = ok(engine.examine(s, 'c_logbook'));
      s = ok(engine.resolveChoice(s, 'c_maul_bargain', bargainOption));
      s = ok(
        engine.resolveChoice(
          s,
          'c_maul_terms',
          bargainOption == 'mb_accept' ? 'mt_learn' : 'mt_break',
        ),
      );
      s = ok(
        engine.submitPuzzle(
          s,
          'p8_gear_alignment',
          const GearsInput([2, 0, 3]),
        ),
      );
      s = ok(engine.move(s, 'clocktower_to_vault'));
      s = ok(
        engine.submitPuzzle(
          s,
          'p16_echo_frequencies',
          solutionFor(content.puzzleById('p16_echo_frequencies')!),
        ),
      );
      s = ok(
        engine.submitPuzzle(
          s,
          'p9_resonance_engine',
          const SequenceInput(['tide', 'ember', 'gale']),
        ),
      );
      expect(s.pendingChoiceIds, ['c_echo_fate']);
      if (finalOption == null) return s;
      return ok(engine.resolveChoice(s, 'c_echo_fate', finalOption));
    }

    test('Guardian, earned by truth, mercy and consent', () {
      final s = playTo('mb_refuse', 'ef_guardian');
      expect(s.endingId, 'echo_guardian');
      expect(s.solvedPuzzleIds, hasLength(content.puzzles.length));
      expect(s.visitedRoomIds, hasLength(5));
    });

    test("Seal, after learning containment", () {
      final s = playTo('mb_accept', 'ef_seal');
      expect(s.endingId, 'seal_echo');
    });

    test('Release, always available', () {
      expect(playTo('mb_accept', 'ef_release').endingId, 'release_echo');
      expect(playTo('mb_refuse', 'ef_release').endingId, 'release_echo');
    });

    test('Guardianship rejects ownership; independent research permits containment', () {
      final bargained = playTo('mb_accept', null);
      final home = engine.resolveChoice(
        bargained,
        'c_echo_fate',
        'ef_guardian',
      );
      expect(home.rejection?.reason, RejectReason.optionDisabled);
      expect(home.rejection?.message, contains('will not trust'));

      final refused = playTo('mb_refuse', null);
      expect(
        engine.resolveChoice(refused, 'c_echo_fate', 'ef_seal').state.endingId,
        'seal_echo',
      );
    });

    test('nothing can happen after the ending', () {
      final s = playTo('mb_refuse', 'ef_guardian');
      expect(
        engine.move(s, 'vault_to_clocktower').rejection?.reason,
        RejectReason.gameOver,
      );
    });
  });
}
