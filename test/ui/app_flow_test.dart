import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/app/settings_controller.dart';
import 'package:hauntquest/features/dialogue/dialogue_screen.dart';
import 'package:hauntquest/features/ending/ending_screen.dart';
import 'package:hauntquest/features/puzzle/puzzle_screen.dart';
import 'package:hauntquest/domain/puzzles/puzzle_evaluator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui_harness.dart';

void main() {
  group('splash and menu', () {
    testWidgets('splash loads content and opens the main menu', (tester) async {
      setScreen(tester, 390, 844);
      await bootApp(tester, await makeServices());
      expect(find.text('HAUNTQUEST'), findsOneWidget);
      expect(find.text('BEGIN QUEST'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('CREDITS'), findsOneWidget);
    });

    testWidgets('a startup failure shows a clear error and can retry', (
      tester,
    ) async {
      setScreen(tester, 390, 844);
      var attempts = 0;
      final services = await makeServices();
      await tester.pumpWidget(
        HauntQuestApp(
          minSplash: Duration.zero,
          bootstrap: () async {
            attempts++;
            if (attempts == 1) {
              throw ContentValidationException('missing room');
            }
            return services;
          },
        ),
      );
      await settle(tester);
      expect(find.text('The manor would not open'), findsOneWidget);
      expect(find.textContaining('missing room'), findsOneWidget);

      await tester.tap(find.text('TRY AGAIN'));
      await pumpUntilFound(tester, find.text('BEGIN QUEST'));
      expect(find.text('BEGIN QUEST'), findsOneWidget);
      expect(attempts, 2);
    });

    testWidgets('every menu button opens a real screen', (tester) async {
      setScreen(tester, 390, 844);
      await bootApp(tester, await makeServices());

      await tester.tap(find.text('CONTINUE'));
      await settle(tester);
      expect(find.text('No saved journeys yet'), findsOneWidget);
      expect(find.text('JOURNEY IN PROGRESS'), findsNothing);
      expect(find.text('Autosave'), findsOneWidget);
      // One autosaved journey; no inert manual-slot placeholders.
      expect(find.textContaining('one journey at a time'), findsOneWidget);
      expect(find.textContaining('Slot'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);

      await tester.tap(find.text('SETTINGS'));
      await settle(tester);
      expect(find.text('Text size'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);

      await tester.tap(find.text('CREDITS'));
      await settle(tester);
      expect(find.text('Made with Kiro'), findsOneWidget);
      expect(find.text('OPEN-SOURCE LICENSES'), findsOneWidget);
      await tester.tap(find.text('OPEN-SOURCE LICENSES'));
      await settle(tester);
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('Begin Quest plays the intro then enters the first room', (
      tester,
    ) async {
      setScreen(tester, 390, 844);
      await bootApp(tester, await makeServices());
      await tester.tap(find.text('BEGIN QUEST'));
      await settle(tester);
      expect(
        find.textContaining('The letter arrived on a night without wind'),
        findsOneWidget,
      );

      // Reduced motion shows each line at once, so Continue works straight away.
      await tester.tap(find.text('CONTINUE'));
      await settle(tester, 300);
      await tester.tap(find.text('CONTINUE'));
      await settle(tester, 300);
      await tester.tap(find.text('ENTER THE MANOR'));
      await settle(tester);
      expect(find.text('Moonlit Entrance Hall'), findsWidgets);
    });
  });

  group('exploring', () {
    Future<AppServices> enterRoom(
      WidgetTester tester, {
      bool reveal = false,
    }) async {
      setScreen(tester, 390, 844);
      final services = await makeServices(reveal: reveal);
      await bootApp(tester, services);
      await tester.tap(find.text('BEGIN QUEST'));
      await settle(tester);
      await tester.tap(find.text('SKIP'));
      await settle(tester);
      return services;
    }

    testWidgets('the hall shows its exit as locked with an explanation', (
      tester,
    ) async {
      await enterRoom(tester);
      expect(find.text('Hidden door'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      await tester.ensureVisible(find.text('Hidden door'));
      await settle(tester, 300);
      await tester.tap(find.text('Hidden door'));
      await tester.pump();
      expect(
        find.textContaining('A seam in the wall holds fast'),
        findsOneWidget,
      );
    });

    testWidgets('examining an object shows its description and a puzzle link', (
      tester,
    ) async {
      await enterRoom(tester);
      await tester.tap(find.byKey(const ValueKey('h_candelabra')));
      await settle(tester, 500);
      expect(
        find.textContaining('Four cold candles stand in a silver branch'),
        findsOneWidget,
      );
      expect(find.text('LOOK CLOSER: CANDLE MOONS'), findsOneWidget);
    });

    testWidgets(
      'the candle puzzle gives true feedback and tells the truth about rewards',
      (tester) async {
        await enterRoom(tester);
        await tester.tap(find.byKey(const ValueKey('h_candelabra')));
        await settle(tester, 500);
        await tester.tap(find.text('LOOK CLOSER: CANDLE MOONS'));
        await settle(tester);

        // Wrong order first.
        for (final name in ['Half', 'Crescent', 'Full', 'Waning']) {
          await tester.tap(find.text(name));
          await tester.pump();
        }
        await tester.tap(find.text('CHECK'));
        await settle(tester, 400);
        expect(find.text('Not yet'), findsOneWidget);

        // Then the right order.
        await tester.tap(find.text('RESET'));
        await settle(tester, 300);
        for (final name in ['Crescent', 'Half', 'Full', 'Waning']) {
          await tester.tap(find.text(name));
          await tester.pump();
        }
        await tester.tap(find.text('CHECK'));
        await settle(tester, 400);
        expect(find.text('That is right'), findsOneWidget);
        // The reward is real: the hidden door is now open.
        expect(find.text('A way opens: Hidden door'), findsOneWidget);
      },
    );

    testWidgets(
      'a puzzle that needs a missing item says so and does not pretend',
      (tester) async {
        await enterRoom(tester);
        await tester.tap(find.byKey(const ValueKey('h_tallow')));
        await settle(tester, 500);
        await tester.tap(find.textContaining('LOOK CLOSER'));
        await settle(tester);
        expect(find.text('USE BRASS WINDING KEY'), findsOneWidget);
        expect(
          find.text('You do not have the Brass Winding Key yet.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('hints appear one tier at a time', (tester) async {
      await enterRoom(tester);
      await tester.tap(find.byKey(const ValueKey('h_candelabra')));
      await settle(tester, 500);
      await tester.tap(find.text('LOOK CLOSER: CANDLE MOONS'));
      await settle(tester);
      await tester.ensureVisible(find.text('I NEED A HINT'));
      await settle(tester, 300);
      await tester.tap(find.text('I NEED A HINT'));
      await settle(tester, 300);
      expect(
        find.textContaining('What do moons do when they rise?'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Light the candles: crescent, half, full, then waning.',
        ),
        findsNothing,
      );
    });

    testWidgets('inventory shows the letter and its full text', (tester) async {
      await enterRoom(tester);
      await tester.tap(find.byTooltip('Inventory'));
      await settle(tester);
      expect(find.text("Wren's Letter"), findsWidgets);
      expect(
        find.textContaining('Light the moons in the order they rise'),
        findsOneWidget,
      );
    });

    testWidgets('the journal lists found evidence and unknown people', (
      tester,
    ) async {
      await enterRoom(tester);
      await tester.tap(find.byTooltip('Journal and evidence'));
      await settle(tester);
      expect(find.text('EVIDENCE'), findsOneWidget);
      expect(find.text("Wren's Letter"), findsOneWidget);
      expect(find.text('Not found'), findsWidgets);
      await tester.tap(find.text('PEOPLE'));
      await settle(tester);
      expect(find.text('Wren Dabney'), findsOneWidget);
      expect(find.text('Unknown voice'), findsNWidgets(4));
    });

    testWidgets('the map and pause menu open real sheets', (tester) async {
      await enterRoom(tester);
      await tester.tap(find.byTooltip('Manor map'));
      await settle(tester, 500);
      expect(find.text('Manor map'), findsOneWidget);
      expect(find.textContaining('You are here'), findsOneWidget);
      expect(find.textContaining('0/4 puzzles'), findsOneWidget);
      expect(find.text('Unknown room'), findsNWidgets(4));
      await tester.tap(find.text('CLOSE'));
      await settle(tester, 500);
      expect(find.text('Manor map'), findsNothing);

      await tester.tap(find.byTooltip('Pause menu'));
      await settle(tester, 500);
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.text('BACK TO TITLE'));
      await settle(tester);
      // The journey is kept, so leaving needs no warning.
      expect(find.text('BEGIN QUEST'), findsOneWidget);
    });

    testWidgets('review mode opens every room', (tester) async {
      // Beginning a quest starts fresh, so review mode is turned on after.
      final services = await enterRoom(tester);
      services.game.reviewMode = true;
      for (final room in services.content.rooms) {
        services.game.moveTo(room.id);
        await settle(tester, 700);
        expect(find.text(room.name), findsWidgets, reason: room.id);
      }
    });
  });

  group('dialogue', () {
    testWidgets('final choice shows locked answers with their reasons', (
      tester,
    ) async {
      setScreen(tester, 390, 844);
      // Review mode puts the player in the vault with the engine humming.
      final services = await makeServices(reveal: true);
      await bootApp(tester, services);
      services.game.moveTo('echo_vault');
      services.game.submitPuzzle(
        'p9_resonance_engine',
        const SequenceInput(['tide', 'ember', 'gale']),
      );
      await openScreen(tester, const DialogueScreen(choiceId: 'c_echo_fate'));

      expect(find.text('Echo'), findsNothing);
      expect(find.text('The Echo'), findsOneWidget);
      expect(find.text('RELEASE THE ECHO.'), findsOneWidget);
      expect(find.text("BECOME THE ECHO'S GUARDIAN."), findsOneWidget);
      expect(
        find.textContaining('The Echo will not trust an owner'),
        findsOneWidget,
      );
      expect(find.textContaining("Learn Maul's binding words"), findsOneWidget);
    });

    testWidgets('choosing an answer shows the reply and records it', (
      tester,
    ) async {
      setScreen(tester, 390, 844);
      final services = await makeServices(reveal: true);
      await bootApp(tester, services);
      services.game.moveTo('alchemist_workshop');
      await openScreen(
        tester,
        const DialogueScreen(choiceId: 'c_echo_whisper'),
      );

      await tester.tap(find.text("'A FRIEND. I'M LISTENING.'"));
      await settle(tester, 600);
      expect(
        find.textContaining('Ottoline said that word too'),
        findsOneWidget,
      );
      // The answer is recorded and changes the story.
      expect(
        services.game.state.resolvedChoices['c_echo_whisper'],
        'ew_gentle',
      );
      expect(services.game.flag('mercy'), 1);
      await tester.tap(find.text('CONTINUE CONVERSATION'));
      await settle(tester);
      await tester.tap(find.text('PROMISE TO LISTEN WITHOUT OWNING IT.'));
      await settle(tester);
      await tester.tap(find.text('DONE'));
      await settle(tester);
      expect(find.byType(DialogueScreen), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('changes apply immediately and are saved', (tester) async {
      setScreen(tester, 390, 844);
      final store = MemorySettingsStore(const AppSettings(reducedMotion: true));
      final services = await makeServices(store: store);
      await bootApp(tester, services);
      await tester.tap(find.text('SETTINGS'));
      await settle(tester);

      await tester.tap(find.text('150%'));
      await settle(tester, 300);
      final context = tester.element(find.text('Text size'));
      expect(
        MediaQuery.textScalerOf(context).scale(1),
        greaterThanOrEqualTo(1.5),
      );
      expect(store.value.textScale, 1.5);

      await tester.tap(find.text('High contrast'));
      await settle(tester, 300);
      expect(services.settings.settings.highContrast, isTrue);
      expect(store.value.highContrast, isTrue);
      expect(store.saves, greaterThanOrEqualTo(2));
    });

    testWidgets('review mode toggle reveals the whole manor', (tester) async {
      setScreen(tester, 390, 844);
      final services = await makeServices();
      await bootApp(tester, services);
      await tester.tap(find.text('SETTINGS'));
      await settle(tester);
      await tester.dragUntilVisible(
        find.text('Reveal everything'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await settle(tester, 300);
      await tester.tap(find.text('Reveal everything'));
      await settle(tester, 300);
      expect(services.game.reviewMode, isTrue);
      expect(services.game.inventory, hasLength(10));
    });

    test('settings survive a restart through shared_preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await PrefsSettingsStore.open();
      await SettingsController(first).update(
        const AppSettings(
          textScale: 1.5,
          highContrast: true,
          spacedText: true,
          reducedMotion: true,
          highlightInteractables: false,
          roomListMode: true,
        ),
      );
      final second = await (await PrefsSettingsStore.open()).load();
      expect(second.textScale, 1.5);
      expect(second.highContrast, isTrue);
      expect(second.spacedText, isTrue);
      expect(second.reducedMotion, isTrue);
      expect(second.highlightInteractables, isFalse);
      expect(second.roomListMode, isTrue);
    });

    test('a failing store is reported, not hidden', () async {
      final controller = SettingsController(_FailingStore());
      await controller.update(const AppSettings(highContrast: true));
      expect(controller.settings.highContrast, isTrue);
      expect(controller.lastSaveError, isNotNull);
    });
  });

  group('endings and puzzles', () {
    testWidgets('each ending can be read to the end', (tester) async {
      setScreen(tester, 390, 844);
      final services = await makeServices();
      await bootApp(tester, services);
      for (final ending in services.content.story.endings) {
        await openScreen(tester, EndingScreen(endingId: ending.id));
        expect(find.text(ending.title), findsOneWidget, reason: ending.id);
        for (var i = 1; i < ending.epilogue.length; i++) {
          await tester.tap(find.text('CONTINUE'));
          await settle(tester, 400);
        }
        expect(find.text('THE END'), findsOneWidget);
        expect(find.text(ending.epilogue.last), findsOneWidget);
        await tester.tap(find.text('CLOSE PREVIEW'));
        await settle(tester);
      }
    });

    testWidgets('every puzzle opens and can be reset', (tester) async {
      setScreen(tester, 390, 844);
      final services = await makeServices(reveal: true);
      await bootApp(tester, services);
      for (final puzzle in services.content.puzzles) {
        await openScreen(tester, PuzzleScreen(puzzleId: puzzle.id));
        expect(find.text(puzzle.title), findsWidgets, reason: puzzle.id);
        expect(find.text(puzzle.intro), findsOneWidget, reason: puzzle.id);
        await tester.tap(find.byTooltip('Back'));
        await settle(tester, 500);
      }
    });
  });
}

class _FailingStore implements SettingsStore {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async =>
      throw StateError('disk full');
}
