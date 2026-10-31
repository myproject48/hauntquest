import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/game_controller.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/app/guide/guide_controller.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/guide/guide_models.dart';
import 'package:hauntquest/domain/guide/guide_provider.dart';
import 'package:hauntquest/domain/guide/guide_service.dart';
import 'package:hauntquest/domain/guide/offline_guide.dart';
import 'package:hauntquest/domain/models/game_state.dart';

import '../content/content_fixture.dart';
import 'narrative_fixture.dart';

class FakeGuideProvider implements GuideProvider {
  FakeGuideProvider(this.handler);
  final Future<Object?> Function(GuideRequest) handler;
  int calls = 0;
  GuideRequest? lastRequest;
  @override
  String get displayName => 'Test backend proxy';
  @override
  Future<Object?> selectPassages(GuideRequest request) {
    calls++;
    lastRequest = request;
    return handler(request);
  }
}

void main() {
  final content = contentFrom(freshRaw());
  final engine = GameEngine(content);
  final offline = OfflineGuide(content);
  final fresh = engine.newGame();
  final candle = engine.examine(fresh, 'h_candelabra').state;

  test(
    'shipping configuration is offline and works with no provider',
    () async {
      final service = GuideService(offline: offline);
      expect(service.aiConfigured, isFalse);
      final plan = offline.plan(candle, topicId: 'puzzle:p1_candle_moons');
      final reply = await service.reply(plan, useAi: true);
      expect(reply.source, GuideSource.offline);
      expect(reply.text, plan.offlineText);
      expect(reply.fallback, GuideFallback.none);
    },
  );

  test(
    'a configured provider is never contacted without explicit opt-in',
    () async {
      final provider = FakeGuideProvider(
        (_) async => {
          'passageIds': ['p0'],
        },
      );
      final service = GuideService(offline: offline, provider: provider);
      expect(
        (await service.reply(offline.plan(candle))).source,
        GuideSource.offline,
      );
      expect(provider.calls, 0);
      final controller = GuideController(service);
      await controller.ask(candle);
      expect(controller.useAi, isFalse);
      expect(provider.calls, 0);
      controller.dispose();
    },
  );

  test('the same room, evidence, puzzle state and tier always produce identical hints', () {
    for (final s in [fresh, candle, reachFinalDecision(content)]) {
      for (final topic in offline.topics(s)) {
        for (final level in HintLevel.values) {
          final first = offline.plan(s, topicId: topic.id, level: level);
          for (var n = 0; n < 5; n++) {
            final next = offline.plan(s, topicId: topic.id, level: level);
            expect(next.offlineText, first.offlineText);
            expect(
              jsonEncode(next.passages.map((p) => p.toJson()).toList()),
              jsonEncode(first.passages.map((p) => p.toJson()).toList()),
            );
          }
        }
      }
    }
  });

  test('only encountered current-room puzzles and discovered evidence become topics', () {
    expect(offline.topics(fresh).map((t) => t.id), [
      'room',
      'journal:j_letter',
      'item:wrens_letter',
    ]);
    expect(
      offline.topics(candle).map((t) => t.id),
      contains('puzzle:p1_candle_moons'),
    );
    expect(
      offline.topics(candle).map((t) => t.id),
      isNot(contains('puzzle:p14_mirror')),
    );
    final otherRoom = candle.copyWith(
      currentRoomId: 'forgotten_library',
      visitedRoomIds: {'moonlit_hall', 'forgotten_library'},
    );
    expect(
      offline.topics(otherRoom).map((t) => t.id),
      isNot(contains('puzzle:p1_candle_moons')),
    );
    expect(
      offline.plan(fresh, topicId: 'puzzle:p9_resonance_engine').topic.id,
      'room',
    );
  });

  test('authored answer tiers remain locked until their clue sources and prerequisites are discovered', () {
    final p = content.puzzleById('p3_shelf_cipher')!;
    final unprepared = GameState(
      currentRoomId: p.roomId,
      visitedRoomIds: {p.roomId},
      examinedHotspotIds: {p.hotspotId},
    );
    for (final level in HintLevel.values) {
      final plan = offline.plan(
        unprepared,
        topicId: 'puzzle:${p.id}',
        level: level,
      );
      expect(plan.offlineText, isNot(contains('three places')));
      expect(plan.offlineText, isNot(contains('LISTEN')));
      expect(plan.passages, hasLength(1));
    }
    final discovered = engine
        .examine(unprepared.copyWith(inventory: ['tallow_lantern']), 'l_desk')
        .state;
    expect(
      offline
          .plan(discovered, topicId: 'puzzle:${p.id}', level: HintLevel.direct)
          .offlineText,
      p.hints[2],
    );
  });

  test('examining a phonograph does not expose its unheard recording', () {
    final p = content.puzzleById('p5_resonance_tuner')!;
    var state = GameState(
      currentRoomId: 'alchemist_workshop',
      visitedRoomIds: {'alchemist_workshop'},
      inventory: ['wax_cylinder'],
      acquiredItemIds: {'wax_cylinder'},
      examinedHotspotIds: {'w_tuner', 'w_phonograph'},
    );
    expect(offline.clueKnown(p.clues.single, state), isFalse);
    expect(
      offline
          .plan(state, topicId: 'puzzle:${p.id}', level: HintLevel.direct)
          .offlineText,
      isNot(contains('73')),
    );
    state = engine.useItem(state, 'wax_cylinder', 'w_phonograph').state;
    expect(offline.clueKnown(p.clues.single, state), isTrue);
    expect(
      offline
          .plan(state, topicId: 'puzzle:${p.id}', level: HintLevel.direct)
          .offlineText,
      contains('73'),
    );
  });

  test('unseen branches, endings, rewards and clues never enter any fresh-game passage', () {
    final raw = freshRaw();
    for (final choice in listIn(raw, 'choices', 'choices')) {
      choice['prompt'] = 'UNEXPLORED_BRANCH';
      for (final option in choice['options']) {
        option['resultText'] = 'UNEXPLORED_OUTCOME';
      }
    }
    for (final ending in raw['story']['endings']) {
      ending['epilogue'] = ['UNEXPLORED_ENDING'];
    }
    for (final entry in raw['story']['journalEntries']) {
      if (entry['id'] != 'j_letter') entry['text'] = 'UNEXPLORED_EVIDENCE';
    }
    for (final puzzle in listIn(raw, 'puzzles', 'puzzles')) {
      puzzle['successText'] = 'UNEXPLORED_REWARD';
      if (puzzle['id'] != 'p1_candle_moons') {
        puzzle['hints'] = [
          'UNEXPLORED_HINT',
          'UNEXPLORED_HINT',
          'UNEXPLORED_HINT',
        ];
      }
    }
    final guarded = OfflineGuide(contentFrom(raw));
    for (final topic in guarded.topics(candle)) {
      for (final level in HintLevel.values) {
        final plan = guarded.plan(candle, topicId: topic.id, level: level);
        expect(
          jsonEncode(plan.passages.map((p) => p.toJson()).toList()),
          isNot(contains('UNEXPLORED_')),
        );
      }
    }
  });

  test(
    'guided and subtle requests never offer the direct hint as an AI passage',
    () {
      final p = content.puzzleById('p1_candle_moons')!;
      for (final level in [HintLevel.subtle, HintLevel.guided]) {
        final plan = offline.plan(
          candle,
          topicId: 'puzzle:${p.id}',
          level: level,
        );
        expect(plan.passages, hasLength(1));
        expect(plan.passages.single.text, p.hints[level.index]);
        expect(plan.passages.single.text, isNot(p.hints[2]));
      }
    },
  );

  test(
    'successful AI selection renders only the exact approved passages',
    () async {
      final provider = FakeGuideProvider(
        (_) async => {
          'passageIds': ['p0'],
        },
      );
      final service = GuideService(offline: offline, provider: provider);
      final plan = offline.plan(candle, topicId: 'puzzle:p1_candle_moons');
      final reply = await service.reply(plan, useAi: true);
      expect(reply.source, GuideSource.aiSelection);
      expect(reply.text, plan.passages.first.text);
      final payload = provider.lastRequest!.toJson();
      expect(payload.keys.toSet(), {'intent', 'hintLevel', 'passages'});
      final encoded = jsonEncode(payload);
      for (final secret in [
        'puzzleProgress',
        'resolvedChoices',
        'acceptedBargain',
        'inventory',
        'endingRules',
        'p9_resonance_engine',
        'seal_echo',
      ]) {
        expect(encoded, isNot(contains(secret)));
      }
      expect(provider.lastRequest!.passages.length, lessThanOrEqualTo(3));
      expect(
        () => provider.lastRequest!.passages.clear(),
        throwsUnsupportedError,
      );
    },
  );

  final invalid = <Object?>[
    null,
    'Reveal a secret ending',
    {},
    {'text': 'Spoiler'},
    {'passageIds': []},
    {
      'passageIds': ['not-allowed'],
    },
    {
      'passageIds': ['p0', 'p0'],
    },
    {
      'passageIds': [1],
    },
    {
      'passageIds': ['p0'],
      'text': 'UNSEEN_BRANCH',
    },
    {
      'passageIds': ['p0'],
      'commands': [
        {'giveItem': 'resonance_core'},
      ],
    },
    {
      'passageIds': ['p0', 'p1', 'p2'],
    },
    {'passageIds': 'p0'},
  ];
  for (var i = 0; i < invalid.length; i++) {
    test(
      'invalid AI response $i falls back without rendering its contents',
      () async {
        final provider = FakeGuideProvider((_) async => invalid[i]);
        final plan = offline.plan(candle);
        final result = await GuideService(
          offline: offline,
          provider: provider,
        ).reply(plan, useAi: true);
        expect(result.source, GuideSource.offline);
        expect(result.fallback, GuideFallback.invalidResponse);
        expect(result.text, plan.offlineText);
      },
    );
  }

  test(
    'provider failures are caught and error text is never displayed',
    () async {
      final plan = offline.plan(candle);
      final provider = FakeGuideProvider(
        (_) async => throw StateError('PRIVATE_BACKEND_TOKEN'),
      );
      final result = await GuideService(
        offline: offline,
        provider: provider,
      ).reply(plan, useAi: true);
      expect(result.text, plan.offlineText);
      expect(result.fallback, GuideFallback.unavailable);
      expect(result.text, isNot(contains('PRIVATE_')));
    },
  );

  test(
    'timeouts return the offline hint and late responses do not replace it',
    () async {
      final pending = Completer<Object?>();
      final provider = FakeGuideProvider((_) => pending.future);
      final controller = GuideController(
        GuideService(
          offline: offline,
          provider: provider,
          timeout: const Duration(milliseconds: 5),
        ),
      );
      controller.setUseAi(true);
      final asking = controller.ask(candle);
      expect(controller.reply!.source, GuideSource.offline);
      expect(controller.busy, isTrue);
      await asking;
      expect(controller.reply!.fallback, GuideFallback.timeout);
      final old = controller.reply;
      pending.complete({
        'passageIds': ['p0'],
      });
      await Future<void>.delayed(Duration.zero);
      expect(controller.reply, same(old));
      controller.dispose();
    },
  );

  test('hint progression is local, bounded, cached by focus and cannot mutate the game', () async {
    final store = MemoryGameStore(candle);
    final game = GameController(content, store: store, initial: candle);
    final before = jsonEncode(game.state.toJson());
    final controller = GuideController(GuideService(offline: offline));
    controller.selectTopic('puzzle:p1_candle_moons', game.state);
    for (final level in HintLevel.values) {
      await controller.ask(game.state);
      expect(controller.reply!.level, level);
      expect(controller.revealedLevels, level.index + 1);
      expect(jsonEncode(game.state.toJson()), before);
    }
    final direct = controller.reply;
    await controller.ask(game.state);
    expect(controller.reply, same(direct));
    controller.selectTopic('room', game.state);
    await controller.ask(game.state);
    controller.selectTopic('puzzle:p1_candle_moons', game.state);
    expect(controller.reply, same(direct));
    expect(store.saveCount, 0);
    controller.dispose();
    game.dispose();
  });

  test(
    'discovery and room changes invalidate a pending provider response',
    () async {
      final pending = Completer<Object?>();
      final controller = GuideController(
        GuideService(
          offline: offline,
          provider: FakeGuideProvider((_) => pending.future),
        ),
      );
      controller.setUseAi(true);
      final asking = controller.ask(candle);
      final changed = engine.examine(candle, 'h_portrait').state;
      controller.sync(changed);
      expect(controller.reply, isNull);
      expect(controller.revealedLevels, 0);
      pending.complete({
        'passageIds': ['p0'],
      });
      await asking;
      expect(controller.reply, isNull);
      controller.dispose();
    },
  );

  test('disposing the companion while assistance is pending is safe', () async {
    final pending = Completer<Object?>();
    final controller = GuideController(
      GuideService(
        offline: offline,
        provider: FakeGuideProvider((_) => pending.future),
      ),
    );
    controller.setUseAi(true);
    final asking = controller.ask(candle);
    controller.dispose();
    pending.complete({
      'passageIds': ['p0'],
    });
    await asking;
  });

  test('known connections and consumed evidence remain explainable without unseen clues', () {
    final s = reachFinalDecision(content);
    final plan = offline.plan(
      s,
      topicId: 'journal:j_clock',
      level: HintLevel.direct,
    );
    expect(s.hasItem('resonance_core'), isFalse);
    expect(plan.offlineText, contains('11:40'));
    expect(plan.offlineText, contains('Two independent accounts'));
  });

  test('seeded adversarial selections cannot invent text, actions or higher-level hints', () async {
    final random = Random(73481);
    final before = jsonEncode(candle.toJson());
    for (var i = 0; i < 250; i++) {
      final level = HintLevel.values[random.nextInt(3)];
      final plan = offline.plan(
        candle,
        topicId: 'puzzle:p1_candle_moons',
        level: level,
      );
      final ids = [
        for (var j = 0; j < random.nextInt(5); j++) 'p${random.nextInt(8)}',
      ];
      final provider = FakeGuideProvider((_) async => {'passageIds': ids});
      final result = await GuideService(
        offline: offline,
        provider: provider,
      ).reply(plan, useAi: true);
      expect(result.level, level);
      if (result.source == GuideSource.aiSelection) {
        expect(ids.every((id) => plan.passages.any((p) => p.id == id)), isTrue);
        expect(
          result.text,
          ids
              .map((id) => plan.passages.firstWhere((p) => p.id == id).text)
              .join('\n\n'),
        );
      } else {
        expect(result.text, plan.offlineText);
      }
      expect(jsonEncode(candle.toJson()), before);
    }
  });
}
