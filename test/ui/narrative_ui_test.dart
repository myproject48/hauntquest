import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/app/settings_controller.dart';
import 'package:hauntquest/core/widgets/typewriter_text.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/features/dialogue/dialogue_screen.dart';
import 'package:hauntquest/features/ending/ending_screen.dart';
import 'package:hauntquest/features/ending/ending_reveal.dart';
import 'package:hauntquest/features/journal/journal_screen.dart';
import 'package:hauntquest/features/room/room_screen.dart';

import '../content/content_fixture.dart';
import '../domain/narrative_fixture.dart';
import 'ui_harness.dart';

void main() {
  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await settle(t, 200);
    await t.tap(f);
    await settle(t, 250);
  }

  testWidgets(
    'typewriter has an accessible skip for every line and tap-to-complete works',
    (t) async {
      setScreen(t, 430, 932);
      final services = await makeServices(
        settings: const AppSettings(),
        reveal: true,
      );
      await bootApp(t, services);
      services.game.moveTo('alchemist_workshop');
      await openScreen(t, const DialogueScreen(choiceId: 'c_echo_whisper'));
      expect(find.byKey(const ValueKey('skip-dialogue-text')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dialogue-option-ew_gentle')),
        findsNothing,
      );
      await tap(t, find.byKey(const ValueKey('skip-dialogue-text')));
      expect(
        find.byKey(const ValueKey('dialogue-option-ew_gentle')),
        findsOneWidget,
      );
      await tap(t, find.byKey(const ValueKey('dialogue-option-ew_gentle')));
      await tap(t, find.byType(TypewriterText));
      expect(find.text('CONTINUE CONVERSATION'), findsOneWidget);
      await tap(t, find.text('CONTINUE CONVERSATION'));
      await tap(t, find.byKey(const ValueKey('skip-dialogue-text')));
      await tap(t, find.byKey(const ValueKey('dialogue-option-ei_person')));
      await tap(t, find.byKey(const ValueKey('skip-dialogue-text')));
      expect(find.text('DONE'), findsOneWidget);
      expect(services.game.flag('guardianshipOath'), 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'read-only transcripts retain the original exchange and offer no choices',
    (t) async {
      setScreen(t, 430, 932);
      final content = contentFrom(freshRaw());
      final state = reachFinalDecision(content, welcome: 'tw_brisk');
      final services = await AppServices.create(
        content: content,
        store: MemorySettingsStore(),
        gameStore: MemoryGameStore(state),
      );
      await bootApp(t, services);
      await openScreen(t, const DialogueScreen(choiceId: 'c_tallow_memory'));
      expect(find.text('CONVERSATION RECORDED'), findsOneWidget);
      expect(find.textContaining('asked me to hurry'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dialogue-option-tm_leave')),
        findsNothing,
      );
      expect(services.game.state, state);
    },
  );

  testWidgets('journal records discoveries, connections, and transcripts', (
    t,
  ) async {
    setScreen(t, 430, 932);
    final content = contentFrom(freshRaw());
    final services = await AppServices.create(
      content: content,
      store: MemorySettingsStore(),
      gameStore: MemoryGameStore(reachFinalDecision(content)),
    );
    await bootApp(t, services);
    await openScreen(t, const JournalScreen());
    await t.dragUntilVisible(
      find.text('CONNECTED DISCOVERIES'),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -250),
    );
    expect(
      find.text('Two independent accounts fix the accident at 11:40.'),
      findsOneWidget,
    );
    await tap(t, find.text('STORY'));
    expect(find.text('FIELD NOTES'), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-j_frequency')), findsOneWidget);
    expect(
      find.textContaining('recorded. New evidence updates'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'a completed saved journey resumes its earned ending after restart',
    (t) async {
      setScreen(t, 430, 932);
      final content = contentFrom(freshRaw());
      final finished = GameEngine(content)
          .resolveChoice(
            reachFinalDecision(content),
            'c_echo_fate',
            'ef_release',
          )
          .state;
      final store = MemoryGameStore(finished);
      final services = await AppServices.create(
        content: content,
        store: MemorySettingsStore(),
        gameStore: store,
      );
      await bootApp(t, services);
      await tap(t, find.text('CONTINUE'));
      expect(find.text('JOURNEY COMPLETE'), findsOneWidget);
      await tap(t, find.text('READ YOUR ENDING'));
      await settle(t);
      expect(find.byType(EndingScreen), findsOneWidget);
      expect(find.text('Release the Echo'), findsOneWidget);
      expect(services.game.state, finished);
    },
  );

  for (final style in ['release', 'seal', 'guardian']) {
    final endingId = {
      'release': 'release_echo',
      'seal': 'seal_echo',
      'guardian': 'echo_guardian',
    }[style]!;
    testWidgets('$style ending has a distinct finite skippable reveal', (
      t,
    ) async {
      setScreen(t, 430, 932);
      final services = await makeServices(settings: const AppSettings());
      await bootApp(t, services);
      await openScreen(t, EndingScreen(endingId: endingId));
      expect(find.byKey(ValueKey('ending-reveal-$style')), findsOneWidget);
      expect(find.text('Skip reveal'), findsOneWidget);
      await tap(t, find.text('Skip reveal'));
      expect(
        t.state<EndingRevealState>(find.byType(EndingReveal)).isComplete,
        isTrue,
      );
      expect(find.text('Skip reveal'), findsNothing);
      expect(t.takeException(), isNull);
    });
    testWidgets('$style reveal respects reduced motion', (t) async {
      setScreen(t, 320, 640);
      await bootApp(t, await makeServices());
      await openScreen(t, EndingScreen(endingId: endingId));
      expect(find.text('Skip reveal'), findsNothing);
      expect(
        t.state<EndingRevealState>(find.byType(EndingReveal)).isComplete,
        isTrue,
      );
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'leaving an unanswered pending conversation does not immediately reopen it',
    (t) async {
      setScreen(t, 430, 932);
      final content = contentFrom(freshRaw());
      final state = GameEngine(content)
          .newGame()
          .copyWith(pendingChoiceIds: ['c_tallow_welcome']);
      final services = await AppServices.create(
        content: content,
        store: MemorySettingsStore(),
        gameStore: MemoryGameStore(state),
      );
      await bootApp(t, services);
      await openScreen(t, const RoomScreen());
      await settle(t);
      expect(find.byType(DialogueScreen), findsOneWidget);
      await tap(t, find.byTooltip('Leave conversation'));
      await settle(t);
      await settle(t);
      expect(find.byType(DialogueScreen), findsNothing);
      expect(services.game.state.pendingChoiceIds, ['c_tallow_welcome']);
      expect(t.takeException(), isNull);
    },
  );
}
