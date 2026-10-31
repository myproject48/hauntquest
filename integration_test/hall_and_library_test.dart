// Plays a complete journey through all five rooms to Release the Echo in
// the compiled app: real assets, storage, dialogue, puzzles, and player input.
//
// Run: flutter test integration_test -d macos   (or an Android device)
// Keep the target app foregrounded: background lifecycle intentionally pauses UI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app.dart';
import 'package:hauntquest/features/dialogue/dialogue_screen.dart';
import 'package:hauntquest/features/ending/ending_screen.dart';
import 'package:hauntquest/app/app_scope.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester t, [int ms = 900]) async {
    await t.pump();
    await t.pump(Duration(milliseconds: ms));
  }

  Future<void> until(WidgetTester t, Finder f) async {
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (f.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $f');
  }

  Future<void> tapObject(WidgetTester t, String id) async {
    await t.tap(find.byKey(ValueKey(id)));
    await wait(t, 600);
  }

  Future<void> close(WidgetTester t) async {
    await t.ensureVisible(find.text('CLOSE').last);
    await t.tap(find.text('CLOSE').last);
    await wait(t, 600);
  }

  Future<void> reveal(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.dragUntilVisible(
        f,
        find.byType(ListView).last,
        const Offset(0, -200),
      );
    }
    await t.ensureVisible(f);
    await wait(t, 300);
  }

  Future<void> exit(WidgetTester t, String label) async {
    await t.ensureVisible(find.text(label));
    await wait(t, 300);
    await t.tap(find.text(label));
    await wait(t, 900);
  }

  Future<void> puzzle(WidgetTester t, String id) async {
    await tapObject(t, id);
    await t.tap(find.textContaining('LOOK CLOSER'));
    await wait(t);
  }

  Future<void> checkAndReturn(WidgetTester t) async {
    await reveal(t, find.text('CHECK'));
    await t.tap(find.text('CHECK'));
    await wait(t, 700);
    expect(find.text('That is right'), findsOneWidget);
    await reveal(t, find.text('BACK TO THE ROOM'));
    await t.tap(find.text('BACK TO THE ROOM'));
    await wait(t);
  }

  testWidgets('play from arrival through five rooms to Release the Echo', (
    t,
  ) async {
    // WidgetTester owns the semantics tree for this test. Keep native AX
    // requests from creating a second handle during window activation.
    t.platformDispatcher.semanticsEnabledTestValue = false;
    addTearDown(t.platformDispatcher.clearSemanticsEnabledTestValue);
    t.view.physicalSize = const Size(390, 844) * t.view.devicePixelRatio;
    addTearDown(t.view.reset);

    await t.pumpWidget(const HauntQuestApp());
    await until(t, find.text('BEGIN QUEST'));
    await wait(t);
    await t.tap(find.text('BEGIN QUEST'));
    // A journey saved by an earlier run asks first; wait for whichever
    // appears so a slow device cannot skip the confirmation by timing.
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (find.text('Start over').evaluate().isNotEmpty ||
          find.text('SKIP').evaluate().isNotEmpty) {
        break;
      }
    }
    if (find.text('Start over').evaluate().isNotEmpty) {
      await t.tap(find.text('Start over'));
      await until(t, find.text('SKIP'));
    }
    await wait(t);
    await t.tap(find.text('SKIP'));
    await until(t, find.text('Moonlit Entrance Hall'));
    await wait(t);

    // Locked door explains itself.
    await exit(t, 'Hidden door');
    expect(
      find.textContaining('A seam in the wall holds fast'),
      findsOneWidget,
    );
    await close(t);

    // Key from the portrait; taken only once.
    await tapObject(t, 'h_portrait');
    expect(find.text('FOUND'), findsOneWidget);
    await close(t);
    await tapObject(t, 'h_portrait');
    expect(find.text('FOUND'), findsNothing);
    await close(t);

    // Candles open the door.
    await puzzle(t, 'h_candelabra');
    for (final n in ['Crescent', 'Half', 'Full', 'Waning']) {
      await t.tap(find.text(n));
      await t.pump();
    }
    await checkAndReturn(t);

    // Wake Tallow with the key; his welcome follows.
    await tapObject(t, 'h_tallow');
    await t.tap(find.text('USE AN ITEM'));
    await wait(t, 400);
    await t.tap(find.bySemanticsLabel('Use Brass Winding Key'));
    await wait(t, 400);
    expect(find.text("Tallow's Lantern"), findsOneWidget);
    await close(t);
    await until(t, find.byType(DialogueScreen));
    await until(t, find.text('THANK HIM WARMLY.'));
    await t.tap(find.text('THANK HIM WARMLY.'));
    await until(t, find.text('CONTINUE CONVERSATION'));
    await t.tap(find.text('CONTINUE CONVERSATION'));
    await until(t, find.text('LISTEN TO HIS MEMORY.'));
    await t.tap(find.text('LISTEN TO HIS MEMORY.'));
    await until(t, find.text('DONE'));
    await t.tap(find.text('DONE'));
    await wait(t);

    // Into the library.
    await exit(t, 'Hidden door');
    expect(find.text('Forgotten Library'), findsWidgets);

    await tapObject(t, 'l_desk');
    expect(find.text("Ottoline's Journal"), findsOneWidget);
    await close(t);

    await puzzle(t, 'l_shelf');
    await t.enterText(find.byType(TextField), 'listen');
    await checkAndReturn(t);

    await tapObject(t, 'l_hearth');
    await close(t);

    await puzzle(t, 'l_blotter');
    await t.tap(find.bySemanticsLabel(RegExp(r'^Torn Page \(Left\)')));
    await t.pump();
    await t.tap(find.bySemanticsLabel(RegExp(r'^Torn Page \(Right\)')));
    await t.pump();
    await checkAndReturn(t);

    await tapObject(t, 'l_ledger');
    await close(t);
    expect(find.textContaining('5/7 explored'), findsOneWidget);

    // Back to the hall: everything is as the player left it.
    await exit(t, 'Back to the hall');
    expect(find.textContaining('Four pale blue flames'), findsOneWidget);

    // And on through the shelf passage.
    await exit(t, 'Hidden door');
    await exit(t, 'Shelf passage');
    expect(find.text("Alchemist's Workshop"), findsWidgets);

    // Dissolve the cabinet lock with the recipe made in the library.
    await tapObject(t, 'w_cabinet');
    await t.tap(find.text('USE AN ITEM'));
    await wait(t, 400);
    await t.tap(find.bySemanticsLabel('Use Vial of Silver Solvent'));
    await wait(t, 400);
    expect(find.text('Wax Cylinder'), findsOneWidget);
    await close(t);

    // Read the recording, then set the tuner by hand.
    await tapObject(t, 'w_phonograph');
    await t.tap(find.text('USE AN ITEM'));
    await wait(t, 400);
    await t.tap(find.bySemanticsLabel('Use Wax Cylinder'));
    await wait(t, 400);
    expect(find.textContaining('Seven, then three'), findsOneWidget);
    await close(t);
    await puzzle(t, 'w_tuner');
    for (var i = 0; i < 7; i++) {
      await reveal(t, find.bySemanticsLabel('Turn up ten'));
      await t.tap(find.bySemanticsLabel('Turn up ten'));
      await t.pump();
    }
    for (var i = 0; i < 3; i++) {
      await t.tap(find.bySemanticsLabel('Turn up one'));
      await t.pump();
    }
    await checkAndReturn(t);

    await exit(t, 'Spiral stair');
    await puzzle(t, 'c_clockface');
    await reveal(t, find.bySemanticsLabel('Hour back one'));
    await t.tap(find.bySemanticsLabel('Hour back one'));
    await t.pump();
    for (var i = 0; i < 4; i++) {
      await reveal(t, find.bySemanticsLabel('Minutes back five'));
      await t.tap(find.bySemanticsLabel('Minutes back five'));
      await t.pump();
    }
    await checkAndReturn(t);
    await tapObject(t, 'c_logbook');
    await close(t);
    await puzzle(t, 'c_gears');
    for (var i = 0; i < 2; i++) {
      final gear = find.bySemanticsLabel(RegExp(r'^Gear 1,'));
      await reveal(t, gear);
      await t.tap(gear);
      await t.pump();
    }
    for (var i = 0; i < 3; i++) {
      final gear = find.bySemanticsLabel(RegExp(r'^Gear 3,'));
      await reveal(t, gear);
      await t.tap(gear);
      await t.pump();
    }
    await checkAndReturn(t);
    await exit(t, 'Vault drawbridge');
    await puzzle(t, 'v_engine');
    for (final name in ['Tide', 'Ember', 'Gale']) {
      await reveal(t, find.text(name));
      await t.tap(find.text(name));
      await t.pump();
    }
    await checkAndReturn(t);
    await until(t, find.byType(DialogueScreen));
    await until(t, find.text('RELEASE THE ECHO.'));
    await reveal(t, find.text('RELEASE THE ECHO.'));
    await t.tap(find.text('RELEASE THE ECHO.'));
    await until(t, find.text('SEE WHAT FOLLOWS'));
    await reveal(t, find.text('SEE WHAT FOLLOWS'));
    await t.tap(find.text('SEE WHAT FOLLOWS'));
    await wait(t);
    await until(t, find.byType(EndingScreen));
    expect(find.text('Release the Echo'), findsOneWidget);
    final game = AppScope.of(t.element(find.byType(EndingScreen))).game;
    expect(game.reviewMode, isFalse);
    expect(game.state.visitedRoomIds, hasLength(5));
    expect(game.endingId, 'release_echo');
    await game.flushSaves();
    expect(game.lastSaveError, isNull);
    await AppScope.of(t.element(find.byType(EndingScreen))).audio.flush();
    expect(
      AppScope.of(t.element(find.byType(EndingScreen))).audio.lastError,
      isNull,
    );
    while (find.text('CONTINUE').evaluate().isNotEmpty) {
      await reveal(t, find.text('CONTINUE'));
      await t.tap(find.text('CONTINUE'));
      await wait(t, 500);
    }
    expect(find.text('THE END'), findsOneWidget);
  });
}
