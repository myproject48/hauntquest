import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/content/definitions/condition.dart';
import 'package:hauntquest/content/definitions/context_text.dart';
import 'package:hauntquest/content/definitions/effect.dart';
import 'package:hauntquest/content/definitions/json_helpers.dart';
import 'package:hauntquest/content/validation/progression_simulator.dart';

import 'content_fixture.dart';

void main() {
  late SimState state;

  setUp(() {
    state = ProgressionSimulator(contentFrom(freshRaw())).initialState()
      ..inventory.add('brass_winding_key')
      ..solved.add('p1_candle_moons')
      ..openExits.add('hall_to_library')
      ..examinedHotspots.add('h_portrait')
      ..resolved.add('c_tallow_welcome')
      ..flags['mercy'] = 2;
  });

  Condition parse(Map<String, Object?> json) => Condition.fromJson(json);

  group('Condition', () {
    test('leaf conditions read progress correctly', () {
      expect(parse({'type': 'always'}).evaluate(state), isTrue);
      expect(
        parse({'type': 'hasItem', 'id': 'brass_winding_key'}).evaluate(state),
        isTrue,
      );
      expect(
        parse({'type': 'hasItem', 'id': 'spare_cog'}).evaluate(state),
        isFalse,
      );
      expect(
        parse({'type': 'puzzleSolved', 'id': 'p1_candle_moons'})
            .evaluate(state),
        isTrue,
      );
      expect(
        parse({'type': 'puzzleSolved', 'id': 'p2_wake_tallow'}).evaluate(state),
        isFalse,
      );
      expect(
        parse({'type': 'flagAtLeast', 'id': 'mercy', 'value': 2})
            .evaluate(state),
        isTrue,
      );
      expect(
        parse({'type': 'flagAtLeast', 'id': 'mercy', 'value': 3})
            .evaluate(state),
        isFalse,
      );
      expect(
        parse({'type': 'flagEquals', 'id': 'mercy', 'value': 2})
            .evaluate(state),
        isTrue,
      );
      expect(
        parse({'type': 'flagEquals', 'id': 'mercy', 'value': 1})
            .evaluate(state),
        isFalse,
      );
      expect(
        parse({'type': 'exitOpen', 'id': 'hall_to_library'}).evaluate(state),
        isTrue,
      );
      expect(
        parse({'type': 'exitOpen', 'id': 'library_to_workshop'})
            .evaluate(state),
        isFalse,
      );
      expect(
        parse({'type': 'examined', 'id': 'h_portrait'}).evaluate(state),
        isTrue,
      );
      expect(
        parse({'type': 'choiceResolved', 'id': 'c_tallow_welcome'})
            .evaluate(state),
        isTrue,
      );
      expect(
        parse({'type': 'visitedRoom', 'id': 'moonlit_hall'}).evaluate(state),
        isTrue,
      );
      expect(
        parse({'type': 'visitedRoom', 'id': 'echo_vault'}).evaluate(state),
        isFalse,
      );
    });

    test('initially open exits count as open', () {
      expect(
        parse({'type': 'exitOpen', 'id': 'library_to_hall'}).evaluate(state),
        isTrue,
      );
    });

    test('all, any and not combine conditions', () {
      final yes = {'type': 'hasItem', 'id': 'brass_winding_key'};
      final no = {'type': 'hasItem', 'id': 'spare_cog'};
      expect(
        parse({
          'type': 'all',
          'of': [yes, yes],
        }).evaluate(state),
        isTrue,
      );
      expect(
        parse({
          'type': 'all',
          'of': [yes, no],
        }).evaluate(state),
        isFalse,
      );
      expect(
        parse({
          'type': 'any',
          'of': [no, yes],
        }).evaluate(state),
        isTrue,
      );
      expect(
        parse({
          'type': 'any',
          'of': [no, no],
        }).evaluate(state),
        isFalse,
      );
      expect(parse({'type': 'not', 'of': no}).evaluate(state), isTrue);
      expect(parse({'type': 'not', 'of': yes}).evaluate(state), isFalse);
    });

    test('rejects malformed conditions', () {
      expect(
        () => parse({'type': 'hasItem'}),
        throwsA(isA<ContentFormatException>()),
      );
      expect(
        () => parse({'type': 'nope'}),
        throwsA(isA<ContentFormatException>()),
      );
    });
  });

  group('Effect', () {
    test('parses every effect type', () {
      Effect e(Map<String, Object?> json) => Effect.fromJson(json);
      expect(e({'type': 'giveItem', 'id': 'a'}), isA<GiveItem>());
      expect(e({'type': 'consumeItem', 'id': 'a'}), isA<ConsumeItem>());
      expect(e({'type': 'setFlag', 'id': 'a', 'value': 1}), isA<SetFlag>());
      expect(e({'type': 'addFlag', 'id': 'a', 'amount': 1}), isA<AddFlag>());
      expect(e({'type': 'openExit', 'id': 'a'}), isA<OpenExit>());
      expect(e({'type': 'startChoice', 'id': 'a'}), isA<StartChoice>());
      expect(
        () => e({'type': 'explode', 'id': 'a'}),
        throwsA(isA<ContentFormatException>()),
      );
    });

    test('applying effects is idempotent for items and clamps flags', () {
      state
        ..apply(const GiveItem('spare_cog'))
        ..inventory.remove('spare_cog')
        ..apply(const GiveItem('spare_cog'));
      expect(
        state.inventory.contains('spare_cog'),
        isFalse,
        reason: 'a consumed item must not be granted a second time',
      );
      state
        ..apply(const AddFlag('mercy', 5))
        ..apply(const SetFlag('truthFragments', 99));
      expect(state.flag('mercy'), 3);
      expect(state.flag('truthFragments'), 5);
    });
  });

  group('ContextText', () {
    test('uses the first matching variant, else the base text', () {
      final text = ContextText.fromJson({
        'base': 'plain',
        'variants': [
          {
            'when': {'type': 'flagAtLeast', 'id': 'mercy', 'value': 3},
            'text': 'never',
          },
          {
            'when': {'type': 'flagAtLeast', 'id': 'mercy', 'value': 1},
            'text': 'kind',
          },
        ],
      });
      expect(text.resolve(state), 'kind');
      state.flags['mercy'] = 0;
      expect(text.resolve(state), 'plain');
      expect(text.allTexts, ['plain', 'never', 'kind']);
    });

    test('accepts a plain string', () {
      expect(ContextText.fromJson('hello').resolve(state), 'hello');
    });
  });
}
