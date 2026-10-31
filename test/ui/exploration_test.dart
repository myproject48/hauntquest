import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/domain/puzzles/puzzle_evaluator.dart';
import 'package:hauntquest/features/dialogue/dialogue_screen.dart';
import 'package:hauntquest/features/room/room_screen.dart';
import 'package:hauntquest/features/room/room_stage.dart';

import 'ui_harness.dart';

/// Drives the real app through the Moonlit Entrance Hall and the Forgotten
/// Library, the way a player would: by tapping objects, exits and buttons.
void main() {
  late AppServices services;

  Future<void> enterHall(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    setScreen(tester, size.width, size.height);
    services = await makeServices();
    await bootApp(tester, services);
    await tester.tap(find.text('BEGIN QUEST'));
    await settle(tester);
    await tester.tap(find.text('SKIP'));
    await settle(tester);
    expect(find.byType(RoomScreen), findsOneWidget);
  }

  /// Taps an object in the scene and waits for its sheet.
  Future<void> tapObject(WidgetTester tester, String hotspotId) async {
    await tester.tap(find.byKey(ValueKey(hotspotId)));
    await settle(tester, 500);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tap(find.text('CLOSE').last);
    await settle(tester, 500);
  }

  /// Taps an exit row in the room panel, scrolling it into view first.
  Future<void> tapExit(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await settle(tester, 200);
    await tester.tap(find.text(label));
    await settle(tester, 700);
  }

  Future<void> openPuzzle(WidgetTester tester, String hotspotId) async {
    await tapObject(tester, hotspotId);
    await tester.tap(find.textContaining('LOOK CLOSER'));
    await settle(tester);
  }

  /// Scrolls the puzzle screen's lazily built list until [finder] exists.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        finder,
        find.byType(ListView).last,
        const Offset(0, -200),
      );
    }
    await tester.ensureVisible(finder);
    await settle(tester, 200);
  }

  Future<void> check(WidgetTester tester) async {
    await reveal(tester, find.text('CHECK'));
    await tester.tap(find.text('CHECK'));
    await settle(tester, 500);
  }

  Future<void> backToRoom(WidgetTester tester) async {
    await reveal(tester, find.text('BACK TO THE ROOM'));
    await tester.tap(find.text('BACK TO THE ROOM'));
    await settle(tester);
  }

  String room() => services.game.currentRoomId;

  HotspotKind kind(String id) =>
      hotspotKindOf(services.game, services.content.hotspotById(id)!);

  group('object collection and repeated interactions', () {
    testWidgets('the portrait gives the key once, then only its repeat text', (
      tester,
    ) async {
      await enterHall(tester);
      expect(kind('h_portrait'), HotspotKind.examine);

      await tapObject(tester, 'h_portrait');
      expect(find.text('FOUND'), findsOneWidget);
      expect(find.text('Brass Winding Key'), findsOneWidget);
      expect(services.game.inventory, contains('brass_winding_key'));
      await closeSheet(tester);
      expect(kind('h_portrait'), HotspotKind.done);

      // Feedback banner announces the pickup.
      expect(
        find.text('Added to inventory: Brass Winding Key'),
        findsOneWidget,
      );

      await tapObject(tester, 'h_portrait');
      expect(find.text('FOUND'), findsNothing);
      expect(find.textContaining('Listen twice'), findsOneWidget);
      expect(
        services.game.inventory.where((i) => i == 'brass_winding_key'),
        hasLength(1),
      );
    });

    testWidgets('a wrong item does nothing and says so', (tester) async {
      await enterHall(tester);
      await tapObject(tester, 'h_front_door');
      await tester.tap(find.text('USE AN ITEM'));
      await settle(tester, 300);
      await tester.tap(find.bySemanticsLabel("Use Wren's Letter"));
      await settle(tester, 300);
      expect(find.textContaining('nothing happens'), findsOneWidget);
      expect(services.game.inventory, ['wrens_letter']);
    });
  });

  group('locked states and unlocking', () {
    testWidgets(
      'the hidden door explains itself and points at the candelabra',
      (tester) async {
        await enterHall(tester);
        await tapExit(tester, 'Hidden door');
        expect(
          find.textContaining('A seam in the wall holds fast'),
          findsOneWidget,
        );
        expect(
          find.textContaining('silver candelabra'),
          findsOneWidget,
          reason: 'a hint, not the answer',
        );
        expect(find.textContaining('crescent'), findsNothing);
        expect(room(), 'moonlit_hall');
        await closeSheet(tester);
      },
    );

    testWidgets(
      'solving the candles opens the door and the player can walk through',
      (tester) async {
        await enterHall(tester);
        await openPuzzle(tester, 'h_candelabra');
        for (final name in ['Crescent', 'Half', 'Full', 'Waning']) {
          await tester.tap(find.text(name));
          await tester.pump();
        }
        await check(tester);
        expect(find.text('That is right'), findsOneWidget);
        expect(find.text('A way opens: Hidden door'), findsOneWidget);
        await backToRoom(tester);

        expect(kind('h_candelabra'), HotspotKind.done);
        await tapExit(tester, 'Hidden door');
        expect(room(), 'forgotten_library');
        expect(find.text('Forgotten Library'), findsWidgets);
      },
    );

    testWidgets('library objects stay locked until there is light', (
      tester,
    ) async {
      await enterHall(tester);
      services.game.submitPuzzle(
        'p1_candle_moons',
        const SequenceInput(['crescent', 'half', 'full', 'waning']),
      );
      await settle(tester);
      await tapExit(tester, 'Hidden door');
      expect(kind('l_desk'), HotspotKind.locked);

      await tapObject(tester, 'l_desk');
      expect(find.textContaining('too dark'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
      expect(find.text('USE AN ITEM'), findsNothing);
      expect(services.game.inventory, isNot(contains('ottoline_journal')));
    });

    testWidgets('the map refuses rooms that are not open yet', (tester) async {
      await enterHall(tester);
      await tester.tap(find.byTooltip('Manor map'));
      await settle(tester, 500);
      // Unknown rooms cannot be tapped.
      await tester.tap(find.text('Unknown room').first, warnIfMissed: false);
      await settle(tester, 300);
      expect(room(), 'moonlit_hall');
    });
  });

  group('end to end', () {
    testWidgets('the Entrance Hall and Library can be fully explored', (
      tester,
    ) async {
      await enterHall(tester);

      // --- Moonlit Entrance Hall
      await tapObject(tester, 'h_portrait');
      await closeSheet(tester);

      await openPuzzle(tester, 'h_candelabra');
      for (final name in ['Crescent', 'Half', 'Full', 'Waning']) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
      await check(tester);
      await backToRoom(tester);

      // Wake Tallow with the key from the object's own sheet.
      await tapObject(tester, 'h_tallow');
      await tester.tap(find.text('USE AN ITEM'));
      await settle(tester, 300);
      await tester.tap(find.bySemanticsLabel('Use Brass Winding Key'));
      await settle(tester, 300);
      expect(find.textContaining('two lamp-bright eyes'), findsOneWidget);
      expect(find.text("Tallow's Lantern"), findsOneWidget);
      await closeSheet(tester);

      // His welcome opens by itself once the room is back on top.
      await settle(tester);
      expect(find.byType(DialogueScreen), findsOneWidget);
      expect(find.text('Tallow'), findsOneWidget);
      await tester.tap(find.text('THANK HIM WARMLY.'));
      await settle(tester, 500);
      expect(find.textContaining('Most kind'), findsOneWidget);
      await tester.tap(find.text('CONTINUE CONVERSATION'));
      await settle(tester);
      await tester.tap(find.text('LISTEN TO HIS MEMORY.'));
      await settle(tester);
      await tester.tap(find.text('DONE'));
      await settle(tester);
      expect(services.game.flag('mercy'), 1);
      expect(find.byType(DialogueScreen), findsNothing);

      for (final id in ['h_front_door', 'h_guest_table']) {
        await tapObject(tester, id);
        await closeSheet(tester);
      }
      expect(
        find.textContaining(
          '5/${services.game.currentRoom.hotspots.length} explored',
        ),
        findsOneWidget,
      );

      // --- Forgotten Library
      await tapExit(tester, 'Hidden door');
      expect(room(), 'forgotten_library');

      await tapObject(tester, 'l_desk');
      expect(find.text("Ottoline's Journal"), findsOneWidget);
      await closeSheet(tester);

      await openPuzzle(tester, 'l_shelf');
      await tester.enterText(find.byType(TextField), 'listen');
      await check(tester);
      expect(find.text('That is right'), findsOneWidget);
      expect(find.text('A way opens: Shelf passage'), findsOneWidget);
      await backToRoom(tester);

      await tapObject(tester, 'l_hearth');
      expect(find.text('Torn Page (Right)'), findsOneWidget);
      await closeSheet(tester);

      await openPuzzle(tester, 'l_blotter');
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Torn Page \(Left\)')));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Torn Page \(Right\)')));
      await tester.pump();
      await check(tester);
      expect(find.textContaining('Vial of Silver Solvent'), findsWidgets);
      await backToRoom(tester);

      await tapObject(tester, 'l_ledger');
      expect(find.textContaining('E. MAUL, INVESTOR'), findsOneWidget);
      await closeSheet(tester);

      expect(
        find.textContaining(
          '5/${services.game.currentRoom.hotspots.length} explored',
        ),
        findsOneWidget,
      );
      expect(services.game.state.solvedPuzzleIds, {
        'p1_candle_moons',
        'p2_wake_tallow',
        'p3_shelf_cipher',
        'p4_torn_pages',
      });
      expect(services.game.inventory, [
        'wrens_letter',
        'brass_winding_key',
        'tallow_lantern',
        'ottoline_journal',
        'silver_solvent',
      ]);
      expect(services.game.flag('truthFragments'), 2);

      // The shelf passage now leads on.
      await tapExit(tester, 'Shelf passage');
      expect(room(), 'alchemist_workshop');
    });
  });

  group('state persists across navigation', () {
    testWidgets(
      'inventory, journal, other rooms and the title screen keep progress',
      (tester) async {
        await enterHall(tester);
        await tapObject(tester, 'h_portrait');
        await closeSheet(tester);
        final before = services.game.state;

        // Inventory and back.
        await tester.tap(find.byTooltip('Inventory'));
        await settle(tester);
        expect(find.text('Brass Winding Key'), findsWidgets);
        await tester.tap(find.byTooltip('Back'));
        await settle(tester);

        // Journal and back.
        await tester.tap(find.byTooltip('Journal and evidence'));
        await settle(tester);
        expect(find.text('Brass Winding Key'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await settle(tester);
        expect(kind('h_portrait'), HotspotKind.done);

        // To the library and back through the doors.
        services.game.submitPuzzle(
          'p1_candle_moons',
          const SequenceInput(['crescent', 'half', 'full', 'waning']),
        );
        await settle(tester);
        await tapExit(tester, 'Hidden door');
        await tapExit(tester, 'Back to the hall');
        expect(room(), 'moonlit_hall');
        expect(services.game.examined('h_portrait'), isTrue);
        expect(services.game.puzzleSolved('p1_candle_moons'), isTrue);

        // To the title and back with Continue.
        await tester.tap(find.byTooltip('Pause menu'));
        await settle(tester, 500);
        await tester.tap(find.text('BACK TO TITLE'));
        await settle(tester);
        await tester.tap(find.text('CONTINUE'));
        await settle(tester);
        expect(find.text('JOURNEY IN PROGRESS'), findsOneWidget);
        await tester.tap(find.text('RESUME'));
        await settle(tester);
        expect(find.byType(RoomScreen), findsOneWidget);
        expect(services.game.inventory, before.inventory);
        expect(services.game.examined('h_portrait'), isTrue);
      },
    );

    testWidgets('Begin Quest asks before replacing a journey', (tester) async {
      await enterHall(tester);
      await tapObject(tester, 'h_portrait');
      await closeSheet(tester);
      await tester.tap(find.byTooltip('Pause menu'));
      await settle(tester, 500);
      await tester.tap(find.text('BACK TO TITLE'));
      await settle(tester);

      await tester.tap(find.text('BEGIN QUEST'));
      await settle(tester, 500);
      expect(find.text('Begin a new quest?'), findsOneWidget);
      await tester.tap(find.text('Keep my journey'));
      await settle(tester, 500);
      expect(services.game.examined('h_portrait'), isTrue);

      await tester.tap(find.text('BEGIN QUEST'));
      await settle(tester, 500);
      await tester.tap(find.text('Start over'));
      await settle(tester);
      await tester.tap(find.text('SKIP'));
      await settle(tester);
      expect(services.game.examined('h_portrait'), isFalse);
      expect(services.game.inventory, ['wrens_letter']);
    });
  });

  group('hotspots are positioned to match the art on every screen size', () {
    for (final size in const [
      Size(320, 640),
      Size(430, 932),
      Size(820, 1180),
      Size(1280, 800),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        await enterHall(tester, size: size);
        final stage = tester.getRect(find.byType(RoomStage));
        // The 3:4 scene is centered inside the stage area.
        var w = stage.width;
        var h = w / RoomStage.aspect;
        if (h > stage.height) {
          h = stage.height;
          w = h * RoomStage.aspect;
        }
        final scene = Rect.fromCenter(
          center: stage.center,
          width: w,
          height: h,
        );
        for (final hs in services.game.currentRoom.hotspots) {
          final r = tester.getRect(find.byKey(ValueKey(hs.id)));
          final expected = Rect.fromLTWH(
            scene.left + hs.area.x * scene.width,
            scene.top + hs.area.y * scene.height,
            hs.area.w * scene.width,
            hs.area.h * scene.height,
          );
          // Same center; at least as large as the art and the 48 dp minimum.
          expect(
            (r.center - expected.center).distance,
            lessThan(1.0),
            reason: hs.id,
          );
          expect(
            r.width,
            greaterThanOrEqualTo(expected.width - 0.5),
            reason: hs.id,
          );
          expect(r.width, greaterThanOrEqualTo(48), reason: hs.id);
          expect(r.height, greaterThanOrEqualTo(48), reason: hs.id);
          expect(scene.inflate(24).contains(r.center), isTrue, reason: hs.id);
        }
      });
    }
  });
}
