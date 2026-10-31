import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/content/definitions/json_helpers.dart';

import 'content_fixture.dart';

/// Negative tests: break the real content in one specific way and confirm
/// the validator reports the matching problem.
void main() {
  Map<String, dynamic> puzzle(Map<String, dynamic> raw, String id) =>
      byId(listIn(raw, 'puzzles', 'puzzles'), id);

  group('unique identifiers', () {
    test('detects a duplicated item id', () {
      final raw = freshRaw();
      final items = listIn(raw, 'items', 'items');
      items.add(Map<String, dynamic>.from(items.first as Map));
      expect(validateRaw(raw).hasCode('duplicate_id'), isTrue);
    });

    test('detects a duplicated hotspot id across rooms', () {
      final raw = freshRaw();
      hotspotIn(raw, 'l_desk')['id'] = 'h_portrait';
      expect(validateRaw(raw).hasCode('duplicate_id'), isTrue);
    });

    test('detects a duplicated choice option id', () {
      final raw = freshRaw();
      final choices = listIn(raw, 'choices', 'choices');
      final options = byId(choices, 'c_echo_whisper')['options'] as List;
      (options[1] as Map<String, dynamic>)['id'] = 'tw_kind';
      expect(validateRaw(raw).hasCode('duplicate_id'), isTrue);
    });
  });

  group('valid references', () {
    test('detects an exit that points to a missing room', () {
      final raw = freshRaw();
      exitIn(raw, 'hall_to_library')['toRoomId'] = 'nowhere';
      expect(validateRaw(raw).hasCode('unknown_reference'), isTrue);
    });

    test('detects an effect that grants an unknown item', () {
      final raw = freshRaw();
      (puzzle(raw, 'p1_candle_moons')['onSolved'] as List).add({
        'type': 'giveItem',
        'id': 'ghost_item',
      });
      expect(validateRaw(raw).hasCode('unknown_reference'), isTrue);
    });

    test('detects a condition that names an unknown puzzle', () {
      final raw = freshRaw();
      hotspotIn(raw, 'c_logbook')['requires'] = {
        'type': 'puzzleSolved',
        'id': 'p99_missing',
      };
      expect(validateRaw(raw).hasCode('unknown_reference'), isTrue);
    });

    test('detects a choice with an unknown speaker', () {
      final raw = freshRaw();
      byId(listIn(raw, 'choices', 'choices'), 'c_maul_bargain')['speakerId'] =
          'nobody';
      expect(validateRaw(raw).hasCode('unknown_reference'), isTrue);
    });

    test('rejects an unknown condition type when parsing', () {
      final raw = freshRaw();
      hotspotIn(raw, 'c_logbook')['requires'] = {'type': 'bogus'};
      expect(() => contentFrom(raw), throwsA(isA<ContentFormatException>()));
    });
  });

  group('reachable rooms', () {
    test('detects a room that nothing opens', () {
      final raw = freshRaw();
      (puzzle(raw, 'p1_candle_moons')['onSolved'] as List).clear();
      final report = validateRaw(raw);
      expect(report.hasCode('unreachable_room'), isTrue);
      expect(report.hasCode('missing_dependency'), isTrue);
    });
  });

  group('valid item requirements', () {
    test('detects a puzzle requiring an unknown item', () {
      final raw = freshRaw();
      (puzzle(raw, 'p6_corroded_cabinet')['requiresItems'] as List).add(
        'ghost',
      );
      expect(validateRaw(raw).hasCode('unknown_reference'), isTrue);
    });

    test('detects a required item that nothing grants', () {
      final raw = freshRaw();
      (hotspotIn(raw, 'h_portrait')['onExamine'] as List).clear();
      final report = validateRaw(raw);
      expect(report.hasCode('item_never_granted'), isTrue);
      expect(report.hasCode('missing_dependency'), isTrue);
    });

    test('detects consuming an item the puzzle does not require', () {
      final raw = freshRaw();
      (puzzle(raw, 'p1_candle_moons')['consumesItems'] = ['wrens_letter']);
      expect(validateRaw(raw).hasCode('invalid_item_requirement'), isTrue);
    });

    test('detects an item consumed in two places', () {
      final raw = freshRaw();
      final p8 = puzzle(raw, 'p8_gear_alignment');
      (p8['requiresItems'] as List).add('resonance_core');
      (p8['consumesItems'] as List).add('resonance_core');
      expect(validateRaw(raw).hasCode('item_multiple_consumers'), isTrue);
    });

    test('detects a combine slot that is not required', () {
      final raw = freshRaw();
      (puzzle(raw, 'p4_torn_pages')['requiresItems'] as List).removeLast();
      expect(validateRaw(raw).hasCode('invalid_item_requirement'), isTrue);
    });
  });

  group('reachable endings', () {
    test('detects an ending whose trigger can never happen', () {
      final raw = freshRaw();
      final accept =
          (byId(listIn(raw, 'choices', 'choices'), 'c_maul_bargain')['options']
                  as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((o) => o['id'] == 'mb_accept');
      accept['effects'] = <dynamic>[];
      final report = validateRaw(raw);
      expect(report.hasCode('ending_unreachable'), isTrue);
      expect(
        report.issues.any((i) => i.message.contains('keepers_chair')),
        isTrue,
      );
    });

    test('detects a dead end when no final option is enabled', () {
      final raw = freshRaw();
      final release =
          (byId(listIn(raw, 'choices', 'choices'), 'c_echo_fate')['options']
                  as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((o) => o['id'] == 'ef_release');
      release['enabledWhen'] = {
        'type': 'flagAtLeast',
        'id': 'acceptedBargain',
        'value': 1,
      };
      release['disabledReason'] = 'Not yet.';
      expect(validateRaw(raw).hasCode('dead_end'), isTrue);
    });

    test('requires the ending rules to end with an always rule', () {
      final raw = freshRaw();
      final rules =
          (raw['story'] as Map<String, dynamic>)['endingRules'] as List;
      (rules.last as Map<String, dynamic>)['when'] = {
        'type': 'flagEquals',
        'id': 'fate',
        'value': 1,
      };
      expect(validateRaw(raw).hasCode('ending_rules_not_total'), isTrue);
    });
  });

  group('missing or cyclic mandatory dependencies', () {
    test('detects a dependency cycle between puzzles', () {
      final raw = freshRaw();
      // P1 opens the library, but now needs P3, which lives in the library.
      puzzle(raw, 'p1_candle_moons')['unlockWhen'] = {
        'type': 'puzzleSolved',
        'id': 'p3_shelf_cipher',
      };
      final report = validateRaw(raw);
      expect(
        report.hasCode('cyclic_dependency'),
        isTrue,
        reason: report.describe(),
      );
      expect(report.hasCode('unsolvable_mandatory_puzzle'), isTrue);
    });

    test('detects a mandatory puzzle with a clue nobody can read', () {
      final raw = freshRaw();
      // Move the journal's only source behind an impossible flag value.
      hotspotIn(raw, 'l_desk')['requires'] = {
        'type': 'all',
        'of': [
          {'type': 'hasItem', 'id': 'tallow_lantern'},
          {'type': 'puzzleSolved', 'id': 'p9_resonance_engine'},
        ],
      };
      final report = validateRaw(raw);
      expect(report.isValid, isFalse);
      expect(
        report.hasCode('cyclic_dependency') ||
            report.hasCode('missing_dependency'),
        isTrue,
      );
    });

    test('detects a mandatory puzzle with no source for its required item', () {
      final raw = freshRaw();
      puzzle(raw, 'p5_resonance_tuner')['onSolved'] = <dynamic>[];
      final report = validateRaw(raw);
      expect(report.isValid, isFalse);
      expect(report.hasCode('missing_dependency'), isTrue);
    });
  });

  group('puzzle data and writing quality', () {
    test('detects a cipher text that does not decode to its answer', () {
      final raw = freshRaw();
      (puzzle(raw, 'p3_shelf_cipher')['config']
              as Map<String, dynamic>)['cipherText'] =
          'XXXXXX';
      expect(validateRaw(raw).hasCode('invalid_puzzle_config'), isTrue);
    });

    test('detects a dial target outside its range', () {
      final raw = freshRaw();
      (puzzle(raw, 'p5_resonance_tuner')['config']
              as Map<String, dynamic>)['target'] =
          500;
      expect(validateRaw(raw).hasCode('invalid_puzzle_config'), isTrue);
    });

    test('detects a sequence solution that uses an unknown option', () {
      final raw = freshRaw();
      (puzzle(raw, 'p1_candle_moons')['config']
          as Map<String, dynamic>)['solution'] = [
        'crescent',
        'eclipse',
      ];
      expect(validateRaw(raw).hasCode('invalid_puzzle_config'), isTrue);
    });

    test('detects a clue whose text is missing from its source', () {
      final raw = freshRaw();
      (puzzle(raw, 'p7_stopped_hands')['clues'] as List).first['contains'] =
          'twenty to noon';
      expect(validateRaw(raw).hasCode('clue_text_missing'), isTrue);
    });

    test('detects a puzzle with no hint tiers or the wrong number', () {
      final raw = freshRaw();
      (puzzle(raw, 'p2_wake_tallow')['hints'] as List).removeLast();
      expect(validateRaw(raw).hasCode('wrong_hint_count'), isTrue);
    });

    test('detects an early hint that spoils a typed answer', () {
      final raw = freshRaw();
      (puzzle(raw, 'p3_shelf_cipher')['hints'] as List)[0] =
          'The answer is LISTEN.';
      expect(validateRaw(raw).hasCode('hint_spoils_answer'), isTrue);
    });

    test('detects text that is too long for mobile', () {
      final raw = freshRaw();
      byId(listIn(raw, 'items', 'items'), 'spare_cog')['detail'] = 'x' * 600;
      expect(validateRaw(raw).hasCode('text_too_long'), isTrue);
    });

    test('detects a locked exit with no explanation', () {
      final raw = freshRaw();
      (exitIn(raw, 'hall_to_library')).remove('lockedText');
      expect(validateRaw(raw).hasCode('missing_locked_text'), isTrue);
    });

    test('detects a disabled-able option without a reason', () {
      final raw = freshRaw();
      final claim =
          (byId(listIn(raw, 'choices', 'choices'), 'c_echo_fate')['options']
                  as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((o) => o['id'] == 'ef_claim');
      claim.remove('disabledReason');
      expect(validateRaw(raw).hasCode('missing_disabled_reason'), isTrue);
    });

    test('detects a flag set outside its range', () {
      final raw = freshRaw();
      final choice = byId(listIn(raw, 'choices', 'choices'), 'c_echo_fate');
      ((choice['options'] as List).first['effects'] as List).add({
        'type': 'setFlag',
        'id': 'mercy',
        'value': 9,
      });
      expect(validateRaw(raw).hasCode('flag_out_of_range'), isTrue);
    });
  });
}
