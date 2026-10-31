import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/content/definitions/choice_def.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/engine/game_events.dart';
import 'package:hauntquest/domain/models/game_state.dart';

import '../content/content_fixture.dart';
import 'narrative_fixture.dart';

void main() {
  final content = contentFrom(freshRaw());
  final engine = GameEngine(content);

  test('traverses every valid decision branch from a fresh game to all three endings', () {
    final reached = <String>{};
    final visitedOptions = <String>{};
    var branches = 0;
    for (final welcome in ['tw_kind', 'tw_ask', 'tw_brisk']) {
      for (final memory in ['tm_listen', 'tm_leave']) {
        for (final whisper in ['ew_gentle', 'ew_demand', 'ew_silent']) {
          for (final identity in ['ei_person', 'ei_weapon']) {
            for (final bargain in ['mb_accept', 'mb_refuse', 'mb_press']) {
              for (final terms in ['mt_learn', 'mt_break']) {
                if (bargain == 'mb_refuse' && terms == 'mt_learn') continue;
                final state = reachFinalDecision(
                  content,
                  welcome: welcome,
                  memory: memory,
                  whisper: whisper,
                  identity: identity,
                  bargain: bargain,
                  terms: terms,
                );
                expect(state.visitedRoomIds, hasLength(5));
                expect(
                  state.solvedPuzzleIds,
                  hasLength(content.puzzles.length),
                );
                expect(state.resolvedChoices, hasLength(6));
                final finalChoice = content.choiceById(
                  content.story.finalChoiceId,
                )!;
                expect(engine.choiceAvailable(state, finalChoice), isTrue);
                for (final option in finalChoice.options) {
                  final result = engine.resolveChoice(
                    state,
                    finalChoice.id,
                    option.id,
                  );
                  if (!engine.optionEnabled(state, option)) {
                    expect(
                      result.rejection?.reason,
                      RejectReason.optionDisabled,
                    );
                    expect(result.state, state);
                    continue;
                  }
                  branches++;
                  expect(result.ok, isTrue);
                  final expected = {
                    'ef_release': 'release_echo',
                    'ef_seal': 'seal_echo',
                    'ef_guardian': 'echo_guardian',
                  }[option.id];
                  expect(result.state.endingId, expected);
                  expect(
                    result.events.whereType<EndingReached>(),
                    hasLength(1),
                  );
                  reached.add(result.state.endingId!);
                  visitedOptions.addAll(result.state.resolvedChoices.values);
                  expect(result.state.pendingChoiceIds, isEmpty);
                }
              }
            }
          }
        }
      }
    }
    expect(branches, greaterThan(300));
    expect(reached, {'release_echo', 'seal_echo', 'echo_guardian'});
    expect(
      visitedOptions,
      content.choices.expand((c) => c.options).map((o) => o.id).toSet(),
    );
  });

  test('containment requires either learned bindings or completed independent research', () {
    final without = reachFinalDecision(content, research: false);
    expect(
      engine.resolveChoice(without, 'c_echo_fate', 'ef_seal').rejection?.reason,
      RejectReason.optionDisabled,
    );
    final learned = reachFinalDecision(
      content,
      research: false,
      bargain: 'mb_accept',
      terms: 'mt_learn',
    );
    expect(
      engine.resolveChoice(learned, 'c_echo_fate', 'ef_seal').state.endingId,
      'seal_echo',
    );
    final independent = reachFinalDecision(content);
    expect(independent.flag('bindingLearned'), 0);
    expect(
      engine
          .resolveChoice(independent, 'c_echo_fate', 'ef_seal')
          .state
          .endingId,
      'seal_echo',
    );
  });

  test('guardianship requires consent, kindness, discoveries, and rejecting ownership', () {
    final good = reachFinalDecision(content);
    expect(
      engine.resolveChoice(good, 'c_echo_fate', 'ef_guardian').state.endingId,
      'echo_guardian',
    );
    for (final bad in [
      reachFinalDecision(content, identity: 'ei_weapon'),
      reachFinalDecision(content, welcome: 'tw_brisk', whisper: 'ew_demand'),
      reachFinalDecision(content, bargain: 'mb_accept', terms: 'mt_learn'),
      good.copyWith(
        solvedPuzzleIds: {...good.solvedPuzzleIds}..remove('p15_evidence'),
      ),
      good.copyWith(
        solvedPuzzleIds: {...good.solvedPuzzleIds}
          ..remove('p16_echo_frequencies'),
      ),
    ]) {
      expect(
        engine
            .resolveChoice(bad, 'c_echo_fate', 'ef_guardian')
            .rejection
            ?.reason,
        RejectReason.optionDisabled,
      );
      expect(engine.resolveChoice(bad, 'c_echo_fate', 'ef_release').ok, isTrue);
    }
    final renounced = reachFinalDecision(
      content,
      bargain: 'mb_accept',
      terms: 'mt_break',
    );
    expect(renounced.flag('acceptedBargain'), 0);
    expect(
      engine.resolveChoice(renounced, 'c_echo_fate', 'ef_guardian').ok,
      isTrue,
    );
  });

  test('the final decision is unavailable before the engine is restored or outside the vault', () {
    final fresh = engine.newGame();
    expect(
      engine.resolveChoice(fresh, 'c_echo_fate', 'ef_release').state,
      fresh,
    );
    final finalState = reachFinalDecision(content);
    final outside = engine.move(finalState, 'vault_to_clocktower').state;
    expect(
      engine.resolveChoice(outside, 'c_echo_fate', 'ef_release').state,
      outside,
    );
  });

  test('captured responses and flags survive saving; replay never grants effects again', () {
    final s = reachFinalDecision(
      content,
      welcome: 'tw_brisk',
      whisper: 'ew_demand',
    );
    final record = s.dialogueRecords['c_echo_identity']!;
    expect(record.prompt, contains('You demanded'));
    final restored = GameState.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
    );
    expect(restored, s);
    for (final node in content.choices.where(
      (c) => restored.choiceResolved(c.id),
    )) {
      final transcript = engine.narrative.transcript(restored, node);
      expect(transcript?.response, restored.dialogueRecords[node.id]!.response);
      final repeat = engine.resolveChoice(
        restored,
        node.id,
        node.options.first.id,
      );
      expect(repeat.state, restored);
      expect(repeat.events.whereType<FlagChanged>(), isEmpty);
    }
    final altered = restored.copyWith(
      flags: {...restored.flags, 'echoAngered': 0},
    );
    expect(
      engine.narrative
          .transcript(altered, content.choiceById('c_echo_identity')!)!
          .prompt,
      record.prompt,
    );
  });

  test('earlier conduct changes later dialogue without duplicating nodes', () {
    final kind = reachFinalDecision(content);
    final brisk = reachFinalDecision(content, welcome: 'tw_brisk');
    expect(
      kind.dialogueRecords['c_tallow_memory']!.prompt,
      contains('dented locket'),
    );
    expect(
      brisk.dialogueRecords['c_tallow_memory']!.prompt,
      contains('asked me to hurry'),
    );
    expect(brisk.dialogueRecords['c_echo_whisper']!.prompt, contains('Hurry'));
    expect(
      content.choices.map((c) => c.id).toSet(),
      hasLength(content.choices.length),
    );
  });

  test('journal and evidence links reveal discoveries once, retain consumed evidence, and avoid spoilers', () {
    final fresh = engine.newGame();
    expect(engine.narrative.journal(fresh).map((e) => e.id), ['j_letter']);
    expect(engine.narrative.connections(fresh), isEmpty);
    final s = reachFinalDecision(content);
    expect(s.hasItem('resonance_core'), isFalse);
    final journal = engine.narrative.journal(s);
    expect(journal.map((e) => e.id).toSet(), hasLength(journal.length));
    expect(
      journal.map((e) => e.id),
      containsAll(['j_clock', 'j_timeline', 'j_frequency', 'j_echo']),
    );
    final connections = engine.narrative.connections(s);
    expect(connections, hasLength(content.story.evidenceLinks.length));
    final ending = engine.resolveChoice(s, 'c_echo_fate', 'ef_guardian').state;
    expect(
      engine.narrative
          .journal(ending)
          .firstWhere((e) => e.id == 'j_engine')
          .text
          .resolve(ending),
      contains('guardian'),
    );
  });

  test('ending decisions freeze narrative state and cannot be replayed', () {
    final s = engine
        .resolveChoice(reachFinalDecision(content), 'c_echo_fate', 'ef_release')
        .state;
    expect(content.choiceById('c_echo_fate')!.replay, DialogueReplay.never);
    expect(
      engine.narrative.transcript(s, content.choiceById('c_echo_fate')!),
      isNull,
    );
    for (final r in [
      engine.resolveChoice(s, 'c_echo_fate', 'ef_seal'),
      engine.examine(s, 'v_engine'),
      engine.acquireItem(s, 'wrens_letter'),
      engine.useItem(s, 'wax_cylinder', 'v_engine'),
    ]) {
      expect(r.state, s);
      expect(r.rejection?.reason, RejectReason.gameOver);
    }
  });

  test(
    'pre-narrative saves schedule missing follow-ups in their original rooms',
    () {
      final json = engine.newGame().toJson()
        ..['resolvedChoices'] = {
          'c_tallow_welcome': 'tw_kind',
          'c_echo_whisper': 'ew_gentle',
          'c_maul_bargain': 'mb_refuse',
        };
      json.remove('dialogueRecords');
      final restored = GameState.fromJson(json);
      expect(restored.pendingChoiceIds, [
        'c_tallow_memory',
        'c_echo_identity',
        'c_maul_terms',
      ]);
      expect(
        engine.choiceAvailable(
          restored,
          content.choiceById('c_tallow_memory')!,
        ),
        isTrue,
      );
      expect(
        engine.choiceAvailable(
          restored,
          content.choiceById('c_echo_identity')!,
        ),
        isFalse,
      );
      expect(GameState.fromJson(restored.toJson()), restored);
    },
  );

  test(
    'legacy ending and option IDs migrate without dropping inventory or flags',
    () {
      for (final pair in [
        ['quiet_dawn', 'release_echo'],
        ['homecoming', 'echo_guardian'],
        ['keepers_chair', 'seal_echo'],
      ]) {
        final json = engine.newGame().toJson()
          ..['endingId'] = pair.first
          ..['resolvedChoices'] = {'c_echo_fate': 'ef_home'};
        json.remove('dialogueRecords');
        final restored = GameState.fromJson(json);
        expect(restored.endingId, pair.last);
        expect(restored.resolvedChoices['c_echo_fate'], 'ef_guardian');
        expect(restored.inventory, ['wrens_letter']);
      }
    },
  );
}
