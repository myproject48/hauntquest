// On-device save and restore: play a little, close the app, start it again
// from platform storage, and resume through Continue.
//
// Run: flutter test integration_test/restart_restore_test.dart -d <device>
//
// The second launch builds new services and re-reads SharedPreferences from
// the platform (prefs.reload), so the restore path is the real one. It is
// still the same OS process, not a cold process start.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app.dart';
import 'package:hauntquest/app/app_scope.dart';
import 'package:hauntquest/features/room/room_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> tapText(WidgetTester t, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await t.dragUntilVisible(
        find.text(text),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
    }
    await t.ensureVisible(find.text(text).last);
    await wait(t, 300);
    await t.tap(find.text(text).last);
    await wait(t);
  }

  testWidgets('progress survives closing and reopening the app', (t) async {
    t.platformDispatcher.semanticsEnabledTestValue = false;
    addTearDown(t.platformDispatcher.clearSemanticsEnabledTestValue);
    t.view.physicalSize = const Size(390, 844) * t.view.devicePixelRatio;
    addTearDown(t.view.reset);

    await t.pumpWidget(const HauntQuestApp());
    await until(t, find.text('BEGIN QUEST'));
    await wait(t);
    await tapText(t, 'BEGIN QUEST');
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (find.text('Start over').evaluate().isNotEmpty ||
          find.text('SKIP').evaluate().isNotEmpty) {
        break;
      }
    }
    if (find.text('Start over').evaluate().isNotEmpty) {
      await tapText(t, 'Start over');
      await until(t, find.text('SKIP'));
    }
    await tapText(t, 'SKIP');
    await until(t, find.byType(RoomScreen));
    await wait(t);

    await t.tap(find.byKey(const ValueKey('h_portrait')));
    await wait(t, 600);
    await tapText(t, 'CLOSE');
    await t.tap(find.byKey(const ValueKey('h_candelabra')));
    await wait(t, 600);
    await t.tap(find.textContaining('LOOK CLOSER'));
    await wait(t);
    for (final n in ['Crescent', 'Half', 'Full', 'Waning']) {
      await t.tap(find.text(n));
      await t.pump();
    }
    await tapText(t, 'CHECK');
    expect(find.text('That is right'), findsOneWidget);
    await tapText(t, 'BACK TO THE ROOM');

    final game = AppScope.of(t.element(find.byType(RoomScreen))).game;
    await game.flushSaves();
    expect(game.lastSaveError, isNull);
    final saved = game.state.toJson();

    // Close the app: unmounting flushes and closes every service.
    await t.pumpWidget(const SizedBox());
    await wait(t, 500);
    await (await SharedPreferences.getInstance()).reload();

    // Open it again.
    await t.pumpWidget(const HauntQuestApp());
    await until(t, find.text('CONTINUE'));
    await wait(t);
    await tapText(t, 'CONTINUE');
    expect(find.text('JOURNEY IN PROGRESS'), findsOneWidget);
    await tapText(t, 'RESUME');
    await until(t, find.byType(RoomScreen));
    final restored = AppScope.of(t.element(find.byType(RoomScreen))).game;
    expect(identical(restored, game), isFalse, reason: 'a new controller');
    expect(restored.state.currentRoomId, saved['currentRoomId']);
    expect(restored.state.inventory, saved['inventory']);
    expect(restored.puzzleSolved('p1_candle_moons'), isTrue);
    expect(restored.state.flags, saved['flags']);
    expect(t.takeException(), isNull);
  });
}
