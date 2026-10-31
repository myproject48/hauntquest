import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/features/inventory/inventory_screen.dart';
import 'package:hauntquest/features/room/room_screen.dart';

import 'ui_harness.dart';

Future<AppServices> enterRoom(
  WidgetTester tester, {
  void Function(AppServices)? configure,
}) async {
  setScreen(tester, 390, 844);
  final services = await makeServices();
  await bootApp(tester, services);
  await openScreen(tester, const RoomScreen());
  await settle(tester);
  configure?.call(services);
  await tester.pump();
  return services;
}

void main() {
  testWidgets(
    'tactile inventory drawer can be opened in the running room screen',
    (tester) async {
      await enterRoom(tester);

      // Open inventory drawer from room screen
      final drawerBtn = find.text('OPEN INVENTORY DRAWER');
      expect(drawerBtn, findsOneWidget);
      await tester.ensureVisible(drawerBtn);
      await tester.tap(drawerBtn);
      await settle(tester);

      // Verify tactile drawer is visible with header and carried item
      expect(find.text('INVENTORY'), findsOneWidget);
      expect(find.text("Wren's Letter"), findsWidgets);

      // Tap close button on the drawer
      await tester.tap(find.byTooltip('Close inventory drawer'));
      await settle(tester);
      expect(find.text('INVENTORY'), findsNothing);
    },
  );

  testWidgets(
    'selecting an item shows clear selected state and inspect details',
    (tester) async {
      await enterRoom(
        tester,
        configure: (s) => s.game.acquireItem('brass_winding_key'),
      );

      // Open drawer
      final drawerBtn = find.text('OPEN INVENTORY DRAWER');
      expect(drawerBtn, findsOneWidget);
      await tester.ensureVisible(drawerBtn);
      await tester.tap(drawerBtn);
      await settle(tester);

      // Select Brass Winding Key
      await tester.tap(find.text('Brass Winding Key').first);
      await settle(tester);

      // Verify inspect button and action dock
      final inspectBtn = find.text('INSPECT');
      expect(inspectBtn, findsOneWidget);

      await tester.tap(inspectBtn);
      await settle(tester);

      // Verify deep inspection bottom sheet
      expect(find.text('CLOSER LOOK'), findsOneWidget);
      expect(
        find.textContaining('The bow is stamped with a single letter: T'),
        findsOneWidget,
      );

      // Close inspection
      await tester.tap(find.text('CLOSE INSPECTION'));
      await settle(tester);
    },
  );

  testWidgets(
    'combine interaction in drawer performs successful combination and shows discovery animation',
    (tester) async {
      final services = await enterRoom(
        tester,
        configure: (s) {
          s.game.acquireItem('torn_page_left');
          s.game.acquireItem('torn_page_right');
        },
      );

      // Open drawer
      final drawerBtn = find.text('OPEN INVENTORY DRAWER');
      expect(drawerBtn, findsOneWidget);
      await tester.ensureVisible(drawerBtn);
      await tester.tap(drawerBtn);
      await settle(tester);

      // Tap Torn Page (Left)
      await tester.tap(find.text('Torn Page (Left)').first);
      await settle(tester);

      // Tap Combine button
      await tester.tap(find.text('COMBINE'));
      await settle(tester);

      // Confirm combine mode active
      expect(find.textContaining('Combining Torn Page (Left)'), findsOneWidget);

      // Tap Torn Page (Right) to combine
      await tester.tap(find.text('Torn Page (Right)').first);
      await settle(tester);

      // Discovery dialog appears celebrating the new item
      expect(find.text('NEW DISCOVERY'), findsOneWidget);
      expect(find.text('Vial of Silver Solvent'), findsWidgets);
      expect(find.textContaining('Silver Solvent'), findsWidgets);

      // Collect into pocket
      await tester.tap(find.text('POCKET ITEM'));
      await settle(tester);

      // Verify game state updated: pages consumed, solvent carried
      expect(services.game.hasItem('silver_solvent'), isTrue);
      expect(services.game.hasItem('torn_page_left'), isFalse);
      expect(services.game.hasItem('torn_page_right'), isFalse);
    },
  );

  testWidgets('invalid combination in drawer shows helpful feedback', (
    tester,
  ) async {
    await enterRoom(
      tester,
      configure: (s) => s.game.acquireItem('brass_winding_key'),
    );

    final drawerBtn = find.text('OPEN INVENTORY DRAWER');
    expect(drawerBtn, findsOneWidget);
    await tester.ensureVisible(drawerBtn);
    await tester.tap(drawerBtn);
    await settle(tester);

    // Select Wren's Letter
    await tester.tap(find.text("Wren's Letter").first);
    await settle(tester);

    // Tap Combine
    await tester.tap(find.text('COMBINE'));
    await settle(tester);

    // Try combining with Brass Winding Key
    await tester.tap(find.text('Brass Winding Key').first);
    await settle(tester);

    // Helpful feedback message is displayed
    expect(
      find.textContaining("Wren's letter is delicate personal correspondence"),
      findsOneWidget,
    );
  });

  testWidgets('using item on room object directly from drawer works', (
    tester,
  ) async {
    final services = await enterRoom(
      tester,
      configure: (s) => s.game.acquireItem('brass_winding_key'),
    );

    // Open inventory drawer in Entrance Hall
    final drawerBtn = find.text('OPEN INVENTORY DRAWER');
    expect(drawerBtn, findsOneWidget);
    await tester.ensureVisible(drawerBtn);
    await tester.tap(drawerBtn);
    await settle(tester);

    // Select Brass Winding Key
    await tester.tap(find.text('Brass Winding Key').first);
    await settle(tester);

    // Tap Use in Room
    await tester.tap(find.text('USE IN ROOM'));
    await settle(tester);

    // Targets shown: Dormant automaton is in Entrance Hall
    final targetChip = find.widgetWithText(ActionChip, 'Dormant automaton');
    expect(targetChip, findsOneWidget);

    await tester.tap(targetChip);
    await settle(tester);

    // Automaton woke up and granted lantern
    expect(services.game.puzzleSolved('p2_wake_tallow'), isTrue);
    expect(services.game.hasItem('tallow_lantern'), isTrue);
  });

  testWidgets('InventoryScreen full page supports combine and inspection', (
    tester,
  ) async {
    setScreen(tester, 390, 844);
    final services = await makeServices();
    services.game.acquireItem('torn_page_left');
    services.game.acquireItem('torn_page_right');

    await bootApp(tester, services);
    await openScreen(tester, const InventoryScreen());
    await settle(tester);

    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Torn Page (Left)'), findsWidgets);

    // Select Torn Page (Left)
    await tester.tap(find.text('Torn Page (Left)').first);
    await settle(tester);

    // Tap Combine button
    final combineBtn = find.text('COMBINE WITH...');
    expect(combineBtn, findsOneWidget);
    await tester.tap(combineBtn);
    await settle(tester);

    // Tap Torn Page (Right)
    await tester.tap(find.text('Torn Page (Right)').first);
    await settle(tester);

    expect(find.text('NEW DISCOVERY'), findsOneWidget);
    expect(find.text('Vial of Silver Solvent'), findsWidgets);

    await tester.tap(find.text('POCKET ITEM'));
    await settle(tester);
    expect(services.game.hasItem('silver_solvent'), isTrue);
  });
}
