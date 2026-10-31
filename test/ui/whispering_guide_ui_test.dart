import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/app/settings_controller.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/guide/guide_provider.dart';
import 'package:hauntquest/features/guide/guide_panel.dart';
import 'package:hauntquest/features/puzzle/puzzle_screen.dart';
import 'package:hauntquest/features/journal/journal_screen.dart';
import 'package:hauntquest/features/room/room_screen.dart';

import '../content/content_fixture.dart';
import '../domain/whispering_guide_test.dart' show FakeGuideProvider;
import 'ui_harness.dart';

void main() {
  Future<AppServices> services({
    GuideProvider? provider,
    double textScale = 1,
    bool contrast = false,
  }) async {
    final content = contentFrom(freshRaw());
    final state = GameEngine(content)
        .examine(GameEngine(content).newGame(), 'h_candelabra')
        .state;
    return AppServices.create(
      content: content,
      store: MemorySettingsStore(
        AppSettings(
          reducedMotion: true,
          textScale: textScale,
          highContrast: contrast,
        ),
      ),
      gameStore: MemoryGameStore(state),
      guideProvider: provider,
    );
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await settle(t, 200);
    await t.tap(finder);
    await settle(t, 200);
  }

  Future<void> openGuide(WidgetTester t, AppServices app, Widget source) async {
    await bootApp(t, app);
    await openScreen(t, source);
    await tap(t, find.byTooltip('The Whispering Guide'));
    expect(find.byType(GuidePanel), findsOneWidget);
  }

  testWidgets(
    'the room companion explicitly labels offline guidance and advances three levels without changing the save',
    (t) async {
      setScreen(t, 390, 844);
      final app = await services();
      final before = jsonEncode(app.game.state.toJson());
      await openGuide(t, app, const RoomScreen());
      expect(
        find.text('Offline, rule-based guidance. No AI service is connected.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('guide-ai-opt-in')), findsNothing);
      for (final label in [
        'A SUBTLE HINT',
        'GUIDE ME FURTHER',
        'SHOW A DIRECT HINT',
      ]) {
        await tap(t, find.text(label));
        expect(find.byKey(const ValueKey('guide-reply')), findsOneWidget);
        expect(jsonEncode(app.game.state.toJson()), before);
      }
      expect(find.text('DIRECT • OFFLINE GUIDANCE'), findsOneWidget);
      expect(find.text('ALL THREE LEVELS SHOWN'), findsOneWidget);
      expect((app.game.store! as MemoryGameStore).saveCount, 0);
      await tap(t, find.byTooltip('Close guide'));
      expect(find.byType(GuidePanel), findsNothing);
      expect(jsonEncode(app.game.state.toJson()), before);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'a puzzle opens its encountered focus and the journal also opens the companion',
    (t) async {
      setScreen(t, 430, 932);
      final app = await services();
      await openGuide(t, app, const PuzzleScreen(puzzleId: 'p1_candle_moons'));
      expect(
        find.descendant(
          of: find.byType(GuidePanel),
          matching: find.text('Candle Moons'),
        ),
        findsOneWidget,
      );
      await tap(t, find.text('A SUBTLE HINT'));
      expect(
        find.textContaining("Wren's letter mentions an order"),
        findsOneWidget,
      );
      await tap(t, find.byTooltip('Close guide'));
      Navigator.of(t.element(find.byType(PuzzleScreen))).pop();
      await settle(t);
      await openScreen(t, const JournalScreen());
      await tap(t, find.byTooltip('The Whispering Guide'));
      expect(find.byType(GuidePanel), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'evidence choices contain only discoveries and can explain them',
    (t) async {
      setScreen(t, 430, 932);
      final app = await services();
      await openGuide(t, app, const RoomScreen());
      await tap(t, find.text('Understand evidence'));
      expect(find.text("Wren's request"), findsOneWidget);
      expect(find.text('The accident reconstructed'), findsNothing);
      await tap(t, find.text('A SUBTLE HINT'));
      await tap(t, find.text('GUIDE ME FURTHER'));
      expect(find.textContaining('twenty to midnight'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'optional assistance is opt-in and rejects raw AI prose with a safe offline reply',
    (t) async {
      setScreen(t, 430, 932);
      final provider = FakeGuideProvider(
        (_) async => {
          'text': 'SECRET_UNEXPLORED_ENDING',
          'giveItem': 'resonance_core',
        },
      );
      final app = await services(provider: provider);
      final before = jsonEncode(app.game.state.toJson());
      await openGuide(t, app, const RoomScreen());
      expect(provider.calls, 0);
      await tap(t, find.text('A SUBTLE HINT'));
      expect(provider.calls, 0);
      await tap(t, find.byKey(const ValueKey('guide-ai-opt-in')));
      await tap(t, find.text('GUIDE ME FURTHER'));
      expect(provider.calls, 1);
      expect(
        find.textContaining('Optional assistance could not be used'),
        findsOneWidget,
      );
      expect(find.textContaining('SECRET_UNEXPLORED_ENDING'), findsNothing);
      expect(find.text('GUIDED • OFFLINE GUIDANCE'), findsOneWidget);
      expect(jsonEncode(app.game.state.toJson()), before);
    },
  );

  testWidgets(
    'successful AI selection is labeled honestly and disabling it restores offline labeling',
    (t) async {
      setScreen(t, 430, 932);
      final provider = FakeGuideProvider(
        (_) async => {
          'passageIds': ['p0'],
        },
      );
      await openGuide(
        t,
        await services(provider: provider),
        const RoomScreen(),
      );
      await tap(t, find.byKey(const ValueKey('guide-ai-opt-in')));
      await tap(t, find.text('A SUBTLE HINT'));
      expect(find.text('SUBTLE • AI-ASSISTED SELECTION'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('guide-ai-opt-in')));
      expect(find.text('SUBTLE • OFFLINE GUIDANCE'), findsOneWidget);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'companion fits ${size.width}x${size.height} at $scale text scale',
        (t) async {
          setScreen(t, size.width, size.height);
          await openGuide(
            t,
            await services(textScale: scale, contrast: scale == 2),
            const RoomScreen(),
          );
          await tap(t, find.text('A SUBTLE HINT'));
          await tap(t, find.text('GUIDE ME FURTHER'));
          await tap(t, find.text('SHOW A DIRECT HINT'));
          expect(find.byKey(const ValueKey('guide-reply')), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
