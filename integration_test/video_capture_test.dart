// Opt-in Android frame capture; run sh tool/video/capture_android.sh.
// Exports screenshots only to a local development tunnel, never a remote service.
// No inventory, flags or puzzle states are injected.
// Plays a complete journey through all five rooms to Release the Echo in
// the compiled app: real assets, storage, dialogue, puzzles, and player input.
//
// Run: flutter test integration_test -d macos   (or an Android device)
// Keep the target app foregrounded: background lifecycle intentionally pauses UI.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app.dart';
import 'package:hauntquest/features/dialogue/dialogue_screen.dart';
import 'package:hauntquest/features/ending/ending_screen.dart';
import 'package:hauntquest/app/app_scope.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('HQ_CAPTURE_VIDEO');
  const settingsOnly = bool.fromEnvironment('HQ_CAPTURE_SETTINGS_ONLY');
  final captureKey = GlobalKey();
  final shots = <Map<String, Object?>>[];
  final exporter = HttpClient();
  Future<void> export(String path, List<int> bytes) async {
    final request = await exporter.postUrl(
      Uri.parse('http://127.0.0.1:8765/$path'),
    );
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close();
    if (response.statusCode != 201) throw StateError('Capture export failed');
    await response.drain<void>();
  }

  Future<void> record(WidgetTester t, String name, [int seconds = 4]) async {
    if ({
      'settings_reading',
      'inventory',
      'journal_discovery',
      'guide_offline',
      'cipher',
      'recording_clue',
      'final_result',
    }.contains(name)) {
      return;
    }
    const frameRate = 10;
    for (var frame = 0; frame < seconds * frameRate; frame++) {
      await t.pump(const Duration(milliseconds: 100));
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await export(
        '$name/${frame.toString().padLeft(6, '0')}.png',
        bytes!.buffer.asUint8List(),
      );
      image.dispose();
    }
    shots.add({'name': name, 'frames': seconds * frameRate, 'fps': frameRate});
    await export(
      'manifest.json',
      utf8.encode(
        jsonEncode({
          'capture': 'Actual Flutter application on Android; instrumented player input',
          'timing':
              'Edited, sampled frames; not a device-performance benchmark',
          'shots': shots,
        }),
      ),
    );
    debugPrint('VIDEO_CAPTURE $name ${seconds}s');
  }

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

  testWidgets('capture real Android journey for the Devpost demo', (t) async {
    addTearDown(() => exporter.close(force: true));
    // WidgetTester owns the semantics tree for this test. Keep native AX
    // requests from creating a second handle during window activation.
    t.platformDispatcher.semanticsEnabledTestValue = false;
    addTearDown(t.platformDispatcher.clearSemanticsEnabledTestValue);
    t.view.physicalSize = const Size(390, 844) * t.view.devicePixelRatio;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      RepaintBoundary(key: captureKey, child: const HauntQuestApp()),
    );
    await until(t, find.text('BEGIN QUEST'));
    await wait(t);
    if (!settingsOnly) await record(t, 'menu', 10);
    await t.tap(find.text('SETTINGS'));
    await wait(t);
    await record(t, 'settings_reading', 3);
    await t.drag(find.byType(ListView).last, const Offset(0, -320));
    await wait(t);
    await t.ensureVisible(find.text('Reduce motion'));
    await wait(t);
    await record(t, 'settings_motion', 3);
    await t.drag(find.byType(ListView).last, const Offset(0, -250));
    await wait(t);
    await t.dragUntilVisible(
      find.textContaining('Master volume'),
      find.byType(ListView).last,
      const Offset(0, -250),
    );
    await Scrollable.ensureVisible(
      t.element(find.text('Mute all sound')),
      alignment: .15,
    );
    await wait(t);
    await record(t, 'settings_sound', 4);
    await t.pageBack();
    await wait(t);
    if (settingsOnly) return;
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

    await record(t, 'hall', 7);

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
    await record(t, 'discovery', 5);
    await close(t);
    await tapObject(t, 'h_portrait');
    expect(find.text('FOUND'), findsNothing);
    await close(t);

    await t.tap(find.bySemanticsLabel('Inventory'));
    await wait(t);
    await record(t, 'inventory', 5);
    await t.pageBack();
    await wait(t);

    // Candles open the door.
    await puzzle(t, 'h_candelabra');
    await record(t, 'candle_input', 3);
    for (final n in ['Full', 'Crescent', 'Half', 'Waning']) {
      await t.tap(find.text(n));
      await t.pump();
    }
    await reveal(t, find.text('CHECK'));
    await t.tap(find.text('CHECK'));
    await wait(t);
    await record(t, 'candle_wrong', 4);
    await reveal(t, find.text('RESET'));
    await t.tap(find.text('RESET'));
    await wait(t);
    for (final n in ['Crescent', 'Half', 'Full', 'Waning']) {
      await t.tap(find.text(n));
      await t.pump();
    }
    await record(t, 'candle_correct', 4);
    await checkAndReturn(t);
    await record(t, 'hall_unlocked', 4);

    // Wake Tallow with the key; his welcome follows.
    await tapObject(t, 'h_tallow');
    await t.tap(find.text('USE AN ITEM'));
    await wait(t, 400);
    await record(t, 'item_use', 4);
    await t.tap(find.bySemanticsLabel('Use Brass Winding Key'));
    await wait(t, 400);
    expect(find.text("Tallow's Lantern"), findsOneWidget);
    await record(t, 'lantern_reward', 4);
    await close(t);
    await until(t, find.byType(DialogueScreen));
    await until(t, find.text('THANK HIM WARMLY.'));
    await record(t, 'dialogue_choice', 5);
    await t.tap(find.text('THANK HIM WARMLY.'));
    await until(t, find.text('CONTINUE CONVERSATION'));
    await record(t, 'dialogue_result', 4);
    await t.tap(find.text('CONTINUE CONVERSATION'));
    await until(t, find.text('LISTEN TO HIS MEMORY.'));
    await t.tap(find.text('LISTEN TO HIS MEMORY.'));
    await until(t, find.text('DONE'));
    await t.tap(find.text('DONE'));
    await wait(t);

    // Into the library.
    await exit(t, 'Hidden door');
    expect(find.text('Forgotten Library'), findsWidgets);
    await record(t, 'library', 7);

    await tapObject(t, 'l_desk');
    expect(find.text("Ottoline's Journal"), findsOneWidget);
    await record(t, 'journal_discovery', 4);
    await close(t);

    await puzzle(t, 'l_shelf');
    await t.tap(find.byTooltip('The Whispering Guide'));
    await wait(t);
    await record(t, 'guide_offline', 4);
    final ask = find.byKey(const ValueKey('ask-guide'));
    await t.ensureVisible(ask);
    await t.tap(ask);
    await wait(t);
    await record(t, 'guide_hint', 5);
    await t.tap(find.byTooltip('Close guide'));
    await wait(t);
    await t.enterText(find.byType(TextField), 'listen');
    await record(t, 'cipher', 4);
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

    await t.tap(find.bySemanticsLabel('Journal and evidence'));
    await wait(t);
    await record(t, 'journal', 6);
    await t.pageBack();
    await wait(t);

    // Back to the hall: everything is as the player left it.
    await exit(t, 'Back to the hall');
    expect(find.textContaining('Four pale blue flames'), findsOneWidget);

    // And on through the shelf passage.
    await exit(t, 'Hidden door');
    await exit(t, 'Shelf passage');
    expect(find.text("Alchemist's Workshop"), findsWidgets);
    await record(t, 'workshop', 7);

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
    await record(t, 'recording_clue', 4);
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
    await record(t, 'clocktower', 7);
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
    await record(t, 'vault', 7);
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
    await record(t, 'final_choices', 6);
    await t.tap(find.text('RELEASE THE ECHO.'));
    await until(t, find.text('SEE WHAT FOLLOWS'));
    await reveal(t, find.text('SEE WHAT FOLLOWS'));
    await record(t, 'final_result', 4);
    await t.tap(find.text('SEE WHAT FOLLOWS'));
    await record(t, 'ending_reveal', 7);
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
    await record(t, 'the_end', 6);
    exporter.close(force: true);
    debugPrint('VIDEO_CAPTURE_COMPLETE exported directly to host');
  }, skip: !enabled);
}
