// Release-readiness flows through the real app: a journey survives an app
// restart (through real SharedPreferences storage), damaged saves are
// reported instead of crashing, a finished journey can be reopened, and the
// back gesture behaves as designed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/app/settings_controller.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/features/dialogue/dialogue_screen.dart';
import 'package:hauntquest/features/ending/ending_screen.dart';
import 'package:hauntquest/features/journal/journal_screen.dart';
import 'package:hauntquest/features/menu/main_menu_screen.dart';
import 'package:hauntquest/features/room/room_screen.dart';
import 'package:hauntquest/features/saves/save_slots_screen.dart';
import 'package:hauntquest/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/content_fixture.dart';
import '../domain/narrative_fixture.dart';
import 'ui_harness.dart';

void main() {
  final content = contentFrom(freshRaw());

  /// Services backed by real SharedPreferences (mocked platform storage),
  /// the same stores the shipping app uses.
  Future<AppServices> prefsServices() async {
    final prefs = await SharedPreferences.getInstance();
    return AppServices.create(
      content: content,
      store: PrefsSettingsStore(prefs),
      gameStore: PrefsGameStore(prefs, content: content),
    );
  }

  /// Unmounts the app (which flushes and closes its services), like the OS
  /// ending the process after the app went to the background.
  Future<void> closeApp(WidgetTester t, AppServices services) async {
    await services.game.flushSaves();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapText(WidgetTester t, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      // Lazily built lists (puzzle screen) only build what is on screen.
      await t.dragUntilVisible(
        find.text(text),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
    }
    await t.ensureVisible(find.text(text).last);
    await settle(t, 200);
    await t.tap(find.text(text).last);
    await settle(t);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a journey with a solved puzzle and a dialogue choice survives '
      'an app restart and resumes through Continue', (t) async {
    setScreen(t, 390, 844);
    final first = await prefsServices();
    await bootApp(t, first);
    await tapText(t, 'BEGIN QUEST');
    await tapText(t, 'SKIP');
    expect(find.byType(RoomScreen), findsOneWidget);

    // Real taps: the portrait key, the candle puzzle, waking Tallow, and
    // his first conversation.
    await t.tap(find.byKey(const ValueKey('h_portrait')));
    await settle(t, 500);
    await tapText(t, 'CLOSE');
    await t.tap(find.byKey(const ValueKey('h_candelabra')));
    await settle(t, 500);
    await t.tap(find.textContaining('LOOK CLOSER'));
    await settle(t);
    for (final n in ['Crescent', 'Half', 'Full', 'Waning']) {
      await t.tap(find.text(n));
      await t.pump();
    }
    await tapText(t, 'CHECK');
    expect(find.text('That is right'), findsOneWidget);
    await tapText(t, 'BACK TO THE ROOM');
    await t.tap(find.byKey(const ValueKey('h_tallow')));
    await settle(t, 500);
    await tapText(t, 'USE AN ITEM');
    await t.tap(find.bySemanticsLabel('Use Brass Winding Key'));
    await settle(t, 400);
    await tapText(t, 'CLOSE');
    await pumpUntilFound(t, find.byType(DialogueScreen));
    await pumpUntilFound(t, find.text('THANK HIM WARMLY.'));
    await tapText(t, 'THANK HIM WARMLY.');

    final before = first.game.state;
    expect(before.puzzleSolved('p1_candle_moons'), isTrue);
    expect(before.resolvedChoices['c_tallow_welcome'], 'tw_kind');
    await closeApp(t, first);

    // Cold start: new services read the stored snapshot back.
    final second = await prefsServices();
    final a = before.toJson(), b = second.game.state.toJson();
    final changed = [
      for (final k in {...a.keys, ...b.keys})
        if ('${a[k]}' != '${b[k]}') k,
    ];
    // Saving also records the journal entries already discovered, so only
    // that list may differ; everything the player did is identical.
    expect(changed, anyOf(isEmpty, ['journalEntryIds']), reason: '$changed');
    await bootApp(t, second);
    await tapText(t, 'CONTINUE');
    expect(find.byType(SaveSlotsScreen), findsOneWidget);
    expect(find.text('JOURNEY IN PROGRESS'), findsOneWidget);
    expect(find.text('Moonlit Entrance Hall'), findsOneWidget);
    await tapText(t, 'RESUME');
    expect(find.byType(RoomScreen), findsOneWidget);
    final game = second.game;
    expect(
      game.inventory,
      containsAll(['brass_winding_key', 'tallow_lantern']),
    );
    expect(game.puzzleSolved('p1_candle_moons'), isTrue);
    expect(game.state.resolvedChoices['c_tallow_welcome'], 'tw_kind');
    expect(t.takeException(), isNull);
    await closeApp(t, second);
  });

  testWidgets('a damaged save is reported on Continue and New Game asks '
      'before replacing it', (t) async {
    SharedPreferences.setMockInitialValues({
      PrefsGameStore.legacyKey: '{"currentRoomId": 77',
    });
    setScreen(t, 390, 844);
    final services = await prefsServices();
    expect(services.game.inProgress, isFalse);
    await bootApp(t, services);
    await tapText(t, 'CONTINUE');
    expect(find.textContaining('could not be restored safely'), findsOneWidget);
    expect(find.text('No saved journeys yet'), findsOneWidget);
    await tapText(t, 'BEGIN QUEST');
    expect(find.text('Begin a new quest?'), findsOneWidget);
    await tapText(t, 'Keep my journey');
    expect(find.byType(SaveSlotsScreen), findsOneWidget);
    // The damaged data is still there until the player confirms.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsGameStore.legacyKey), isNotNull);
    expect(t.takeException(), isNull);
    await closeApp(t, services);
  });

  testWidgets('a finished journey reopens on its ending after a restart', (
    t,
  ) async {
    setScreen(t, 390, 844);
    final engine = GameEngine(content);
    final ended = engine
        .resolveChoice(
          reachFinalDecision(content),
          content.story.finalChoiceId,
          'ef_seal',
        )
        .state;
    expect(ended.endingId, 'seal_echo');
    final services = await AppServices.create(
      content: content,
      store: MemorySettingsStore(const AppSettings(reducedMotion: true)),
      gameStore: MemoryGameStore(ended),
    );
    await bootApp(t, services);
    await tapText(t, 'CONTINUE');
    expect(find.text('JOURNEY COMPLETE'), findsOneWidget);
    await tapText(t, 'READ YOUR ENDING');
    expect(find.byType(EndingScreen), findsOneWidget);
    final screen = t.widget<EndingScreen>(find.byType(EndingScreen));
    expect(screen.endingId, 'seal_echo');
    expect(screen.fromPlay, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('back in a room opens the pause menu, back again closes it, '
      'and Back to title keeps the journey', (t) async {
    setScreen(t, 390, 844);
    final store = MemoryGameStore();
    final services = await AppServices.create(
      content: content,
      store: MemorySettingsStore(const AppSettings(reducedMotion: true)),
      gameStore: store,
    );
    await bootApp(t, services);
    await tapText(t, 'BEGIN QUEST');
    await tapText(t, 'SKIP');
    services.game.examine('h_portrait');
    await settle(t);

    await t.binding.handlePopRoute();
    await settle(t, 500);
    expect(find.text('Paused'), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t, 500);
    expect(find.text('Paused'), findsNothing);
    expect(find.byType(RoomScreen), findsOneWidget);

    // A pushed screen pops normally and returns to the room.
    await t.tap(find.bySemanticsLabel('Journal and evidence'));
    await settle(t);
    expect(find.byType(JournalScreen), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byType(JournalScreen), findsNothing);
    expect(find.byType(RoomScreen), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Pause menu'));
    await settle(t, 500);
    await tapText(t, 'BACK TO TITLE');
    expect(find.byType(MainMenuScreen), findsOneWidget);
    await services.game.flushSaves();
    expect(store.savedState?.inventory, contains('brass_winding_key'));
    await tapText(t, 'CONTINUE');
    expect(find.text('JOURNEY IN PROGRESS'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the Continue screen shows no inert save slots', (t) async {
    setScreen(t, 360, 740);
    final services = await makeServices();
    await bootApp(t, services);
    await tapText(t, 'CONTINUE');
    expect(find.textContaining('Slot'), findsNothing);
    expect(find.text('Empty'), findsNothing);
    expect(find.textContaining('one journey at a time'), findsOneWidget);
  });

  group('ending decisions through the dialogue screen', endingChoiceTests);

  test('review tools follow the build mode (shown in debug and tests, '
      'hidden in release unless HQ_REVIEW_TOOLS=true)', () {
    // Widget tests always run in debug mode.
    expect(reviewToolsEnabled, isTrue);
  });
}

/// Each ending is chosen through the real dialogue screen, starting from a
/// journey the real engine produced by legal play (narrative_fixture.dart).
void endingChoiceTests() {
  final content = contentFrom(freshRaw());
  final cases = <(String, String)>[
    ('RELEASE THE ECHO.', 'release_echo'),
    ('SEAL THE ECHO.', 'seal_echo'),
    ("BECOME THE ECHO'S GUARDIAN.", 'echo_guardian'),
  ];
  for (final (label, endingId) in cases) {
    testWidgets('the final decision "$label" leads to its ending', (t) async {
      setScreen(t, 390, 844);
      final atDecision = reachFinalDecision(content);
      expect(
        atDecision.pendingChoiceIds,
        contains(content.story.finalChoiceId),
      );
      final store = MemoryGameStore(atDecision);
      final services = await AppServices.create(
        content: content,
        store: MemorySettingsStore(const AppSettings(reducedMotion: true)),
        gameStore: store,
      );
      await bootApp(t, services);
      await t.tap(find.text('CONTINUE'));
      await settle(t);
      await t.tap(find.text('RESUME'));
      await settle(t);
      // The pending final conversation opens by itself in the vault.
      await pumpUntilFound(t, find.byType(DialogueScreen));
      await pumpUntilFound(t, find.text(label));
      await t.ensureVisible(find.text(label));
      await settle(t, 200);
      await t.tap(find.text(label));
      await settle(t);
      await pumpUntilFound(t, find.text('SEE WHAT FOLLOWS'));
      await t.ensureVisible(find.text('SEE WHAT FOLLOWS'));
      await settle(t, 200);
      await t.tap(find.text('SEE WHAT FOLLOWS'));
      await settle(t);
      await pumpUntilFound(t, find.byType(EndingScreen));
      expect(services.game.endingId, endingId);
      expect(find.text(content.endingById(endingId)!.title), findsWidgets);
      await services.game.flushSaves();
      expect(store.savedState?.endingId, endingId, reason: 'ending is saved');
      expect(t.takeException(), isNull);
    });
  }
}
