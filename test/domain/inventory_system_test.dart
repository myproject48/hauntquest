import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/game_controller.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/content/game_content.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/engine/game_events.dart';
import 'package:hauntquest/domain/items/item_combinations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/content_fixture.dart';

void main() {
  late GameContent content;
  late GameEngine engine;

  setUp(() {
    content = contentFrom(freshRaw());
    engine = GameEngine(content);
  });

  EngineResult ok(EngineResult r) {
    expect(r.ok, isTrue, reason: r.rejection?.message);
    return r;
  }

  group('Item Pickup and Attributes', () {
    test(
      'story items have unique ids, names, descriptions, and supported icons',
      () {
        final ids = <String>{};
        for (final item in content.items) {
          expect(
            ids.add(item.id),
            isTrue,
            reason: 'Duplicate item id: ${item.id}',
          );
          expect(item.name.trim(), isNotEmpty);
          expect(item.description.resolve(engine.newGame()).trim(), isNotEmpty);
          expect(item.detail.resolve(engine.newGame()).trim(), isNotEmpty);
          expect(item.iconId.trim(), isNotEmpty);
        }
      },
    );

    test('player starts with story start items in inventory', () {
      final s = engine.newGame();
      expect(s.inventory, contains('wrens_letter'));
      expect(s.wasAcquired('wrens_letter'), isTrue);
      expect(s.hasItem('wrens_letter'), isTrue);
    });

    test('picking up an item adds it to inventory and acquiredItemIds', () {
      var s = engine.newGame();
      expect(s.hasItem('brass_winding_key'), isFalse);

      final r = engine.acquireItem(s, 'brass_winding_key');
      expect(r.ok, isTrue);
      expect(
        r.events.whereType<ItemAcquired>().single.itemId,
        'brass_winding_key',
      );

      s = r.state;
      expect(s.hasItem('brass_winding_key'), isTrue);
      expect(s.wasAcquired('brass_winding_key'), isTrue);
      expect(s.inventory.last, 'brass_winding_key');
    });

    test('picking up an item through examining an in-game object works', () {
      var s = engine.newGame();
      // Examining portrait grants brass_winding_key.
      final r = engine.examine(s, 'h_portrait');
      expect(r.ok, isTrue);
      expect(r.itemsAcquired, contains('brass_winding_key'));
      expect(r.state.hasItem('brass_winding_key'), isTrue);
    });
  });

  group('Item Use on Room Objects', () {
    test('using an item on the right object triggers effects', () {
      var s = engine.newGame();
      s = ok(engine.acquireItem(s, 'brass_winding_key')).state;

      final r = engine.useItem(s, 'brass_winding_key', 'h_tallow');
      expect(r.ok, isTrue);
      expect(
        r.events.whereType<PuzzleSolved>().single.puzzleId,
        'p2_wake_tallow',
      );
      expect(r.itemsAcquired, contains('tallow_lantern'));
    });

    test('consumed items are removed only when game rules require it', () {
      var s = engine.newGame();
      s = ok(engine.acquireItem(s, 'brass_winding_key')).state;

      // Brass winding key is NOT consumed by waking Tallow.
      final r1 = engine.useItem(s, 'brass_winding_key', 'h_tallow');
      expect(r1.state.hasItem('brass_winding_key'), isTrue);
      expect(r1.state.consumedItemIds, isNot(contains('brass_winding_key')));

      // In workshop, using silver_solvent on w_cabinet DOES consume it.
      // Move to workshop first.
      var s2 = s.copyWith(currentRoomId: 'alchemist_workshop');
      s2 = ok(engine.acquireItem(s2, 'silver_solvent')).state;
      expect(s2.hasItem('silver_solvent'), isTrue);

      final r2 = engine.useItem(s2, 'silver_solvent', 'w_cabinet');
      expect(r2.ok, isTrue);
      expect(
        r2.events.whereType<ItemConsumed>().single.itemId,
        'silver_solvent',
      );
      expect(r2.state.hasItem('silver_solvent'), isFalse);
      expect(r2.state.consumedItemIds, contains('silver_solvent'));
    });

    test('using an uncarried item is rejected with itemNotCarried', () {
      final s = engine.newGame();
      final r = engine.useItem(s, 'spare_cog', 'h_tallow');
      expect(r.ok, isFalse);
      expect(r.rejection?.reason, RejectReason.itemNotCarried);
    });

    test('using an item on an incompatible object gives helpful feedback', () {
      final s = engine.newGame();
      final r = engine.useItem(s, 'wrens_letter', 'h_front_door');
      expect(r.ok, isFalse);
      expect(r.rejection?.reason, RejectReason.itemDoesNothing);
      expect(r.message, isNotEmpty);
    });
  });

  group('Item Inspection', () {
    test('inspecting carried item records inspection once', () {
      var s = engine.newGame();
      final r1 = engine.inspectItem(s, 'wrens_letter');
      expect(r1.ok, isTrue);
      expect(r1.events.single, isA<ItemInspected>());
      s = r1.state;
      expect(s.inspectedItemIds, contains('wrens_letter'));

      // Repeating inspection produces no duplicate events.
      final r2 = engine.inspectItem(s, 'wrens_letter');
      expect(r2.events, isEmpty);
    });

    test('inspecting uncarried item is rejected', () {
      final s = engine.newGame();
      final r = engine.inspectItem(s, 'resonance_core');
      expect(r.ok, isFalse);
      expect(r.rejection?.reason, RejectReason.itemNotCarried);
    });
  });

  group('Item Combination Validation', () {
    test('successful combination joins recipe items in either order and updates state', () {
      var s = engine.newGame();
      s = ok(engine.acquireItem(s, 'torn_page_left')).state;
      s = ok(engine.acquireItem(s, 'torn_page_right')).state;

      expect(s.hasItem('torn_page_left'), isTrue);
      expect(s.hasItem('torn_page_right'), isTrue);
      expect(s.hasItem('silver_solvent'), isFalse);

      final r = engine.combineItems(s, 'torn_page_left', 'torn_page_right');
      expect(r.ok, isTrue);
      expect(r.message, contains('Silver Solvent'));

      final combined = r.events.whereType<ItemCombined>().single;
      expect(combined.resultItemId, 'silver_solvent');

      final next = r.state;
      expect(next.hasItem('torn_page_left'), isFalse);
      expect(next.hasItem('torn_page_right'), isFalse);
      expect(next.hasItem('silver_solvent'), isTrue);
      expect(
        next.consumedItemIds,
        containsAll(['torn_page_left', 'torn_page_right']),
      );
      expect(next.puzzleSolved('p4_torn_pages'), isTrue);
    });

    test('combination works regardless of argument order', () {
      var s = engine.newGame();
      s = ok(engine.acquireItem(s, 'torn_page_left')).state;
      s = ok(engine.acquireItem(s, 'torn_page_right')).state;

      // Reverse order: right then left.
      final r = engine.combineItems(s, 'torn_page_right', 'torn_page_left');
      expect(r.ok, isTrue);
      expect(r.state.hasItem('silver_solvent'), isTrue);
    });

    test(
      'combining an item with itself provides helpful feedback and is rejected',
      () {
        final s = engine.newGame();
        final r = engine.combineItems(s, 'wrens_letter', 'wrens_letter');
        expect(r.ok, isFalse);
        expect(r.rejection?.reason, RejectReason.cannotCombine);
        expect(
          r.rejection?.message,
          contains('cannot combine an item with itself'),
        );
      },
    );

    test('combining non-carried item is rejected', () {
      final s = engine.newGame();
      final r = engine.combineItems(s, 'wrens_letter', 'torn_page_left');
      expect(r.ok, isFalse);
      expect(r.rejection?.reason, RejectReason.itemNotCarried);
    });

    test(
      'invalid combinations provide rich, in-world explanatory feedback',
      () {
        var s = engine.newGame();
        s = ok(engine.acquireItem(s, 'brass_winding_key')).state;
        s = ok(engine.acquireItem(s, 'spare_cog')).state;

        final r = engine.combineItems(s, 'brass_winding_key', 'spare_cog');
        expect(r.ok, isFalse);
        expect(r.rejection?.reason, RejectReason.cannotCombine);
        expect(r.rejection?.message, contains('brass winding key'));
      },
    );

    test(
      'ItemCombinations catalog provides contextual feedback for all items',
      () {
        expect(
          ItemCombinations.describeInvalid(
            content,
            'torn_page_left',
            'wrens_letter',
          ),
          contains('torn recipe fragment'),
        );
        expect(
          ItemCombinations.describeInvalid(
            content,
            'wrens_letter',
            'tallow_lantern',
          ),
          contains("Wren's letter"),
        );
        expect(
          ItemCombinations.describeInvalid(
            content,
            'tallow_lantern',
            'spare_cog',
          ),
          contains('lantern'),
        );
      },
    );
  });

  group('Duplicate Prevention', () {
    test(
      'acquiring the same item twice is rejected and does not duplicate',
      () {
        var s = engine.newGame();
        expect(s.inventory.where((id) => id == 'wrens_letter').length, 1);

        // Attempt direct re-acquire of starting item.
        final r = engine.acquireItem(s, 'wrens_letter');
        expect(r.ok, isFalse);
        expect(r.rejection?.reason, RejectReason.itemAlreadyAcquired);
        expect(r.state.inventory.where((id) => id == 'wrens_letter').length, 1);
      },
    );

    test('re-examining a hotspot does not re-grant the item', () {
      var s = engine.newGame();
      s = ok(engine.examine(s, 'h_portrait')).state;
      expect(s.inventory.where((id) => id == 'brass_winding_key').length, 1);

      // Examine portrait a second time.
      final r2 = engine.examine(s, 'h_portrait');
      expect(r2.itemsAcquired, isEmpty);
      expect(
        r2.state.inventory.where((id) => id == 'brass_winding_key').length,
        1,
      );
    });

    test('consumed items cannot be acquired again or duplicated', () {
      var s = engine.newGame();
      s = ok(engine.acquireItem(s, 'torn_page_left')).state;
      s = ok(engine.acquireItem(s, 'torn_page_right')).state;
      s = ok(engine.combineItems(s, 'torn_page_left', 'torn_page_right')).state;

      expect(s.hasItem('torn_page_left'), isFalse);
      expect(s.wasAcquired('torn_page_left'), isTrue);

      // Attempting to acquire a consumed item is rejected.
      final r = engine.acquireItem(s, 'torn_page_left');
      expect(r.ok, isFalse);
      expect(r.rejection?.reason, RejectReason.itemAlreadyAcquired);
    });
  });

  group('Persistence Across Application Restart', () {
    test('inventory and progress persist through GameStore and restore on restart', () async {
      final store = MemoryGameStore();
      final controller = GameController(content, store: store);

      // Collect an item and inspect it.
      controller.acquireItem('brass_winding_key');
      controller.inspectItem('brass_winding_key');
      await controller.flushSaves();

      expect(controller.inventory, contains('brass_winding_key'));
      expect(store.savedState, isNotNull);
      expect(store.savedState!.inventory, contains('brass_winding_key'));
      expect(store.savedState!.inspectedItemIds, contains('brass_winding_key'));

      // Simulate application restart: load new controller from persisted state.
      final restoredState = await store.load();
      final restartedController = GameController(
        content,
        store: store,
        initial: restoredState,
      );

      expect(restartedController.inventory, contains('brass_winding_key'));
      expect(
        restartedController.state.inspectedItemIds,
        contains('brass_winding_key'),
      );
      expect(restartedController.hasItem('brass_winding_key'), isTrue);
    });

    test(
      'combined items and consumed items persist accurately across restart',
      () async {
        final store = MemoryGameStore();
        final controller = GameController(content, store: store);

        controller.acquireItem('torn_page_left');
        controller.acquireItem('torn_page_right');
        controller.combineItems('torn_page_left', 'torn_page_right');

        expect(controller.hasItem('silver_solvent'), isTrue);
        expect(controller.hasItem('torn_page_left'), isFalse);
        expect(controller.hasItem('torn_page_right'), isFalse);

        // Simulate app restart after the queued transaction commits.
        await controller.flushSaves();
        final savedState = await store.load();
        final restarted = GameController(
          content,
          store: store,
          initial: savedState,
        );

        expect(restarted.hasItem('silver_solvent'), isTrue);
        expect(restarted.hasItem('torn_page_left'), isFalse);
        expect(
          restarted.state.consumedItemIds,
          containsAll(['torn_page_left', 'torn_page_right']),
        );
        expect(restarted.puzzleSolved('p4_torn_pages'), isTrue);
      },
    );

    test(
      'PrefsGameStore serializes to SharedPreferences and roundtrips GameState',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = PrefsGameStore(prefs);

        var s = engine.newGame();
        s = ok(engine.acquireItem(s, 'spare_cog')).state;
        s = ok(engine.inspectItem(s, 'spare_cog')).state;

        await store.save(s);

        final loaded = await store.load();
        expect(loaded, isNotNull);
        expect(loaded!.inventory, s.inventory);
        expect(loaded.acquiredItemIds, s.acquiredItemIds);
        expect(loaded.inspectedItemIds, s.inspectedItemIds);

        await store.clear();
        expect(await store.load(), isNull);
      },
    );

    test(
      'restarting the journey via controller resets the persisted store',
      () async {
        final store = MemoryGameStore();
        final controller = GameController(content, store: store);

        controller.acquireItem('brass_winding_key');
        await controller.flushSaves();
        expect(store.savedState!.hasItem('brass_winding_key'), isTrue);

        controller.restart();
        await controller.flushSaves();
        expect(store.savedState!.hasItem('brass_winding_key'), isFalse);
        expect(store.savedState!.inventory, content.story.startItems);
      },
    );
  });
}
