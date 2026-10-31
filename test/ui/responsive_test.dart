import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/settings_controller.dart';
import 'package:hauntquest/core/painting/character_portraits.dart';
import 'package:hauntquest/core/painting/ending_scenes.dart';
import 'package:hauntquest/core/painting/hotspot_art.dart';
import 'package:hauntquest/core/painting/item_icons.dart';
import 'package:hauntquest/core/painting/puzzle_art.dart';
import 'package:hauntquest/core/painting/room_art.dart';
import 'package:hauntquest/features/dialogue/dialogue_screen.dart';
import 'package:hauntquest/features/ending/ending_screen.dart';
import 'package:hauntquest/features/inventory/inventory_screen.dart';
import 'package:hauntquest/features/journal/journal_screen.dart';
import 'package:hauntquest/features/puzzle/puzzle_screen.dart';
import 'package:hauntquest/features/room/room_screen.dart';
import 'package:hauntquest/features/saves/save_slots_screen.dart';
import 'package:hauntquest/features/settings/settings_screen.dart';

import '../content/content_fixture.dart';
import 'ui_harness.dart';

/// Screen sizes covering a small phone, a large phone, a tablet in portrait,
/// and a tablet in landscape.
const _sizes = <String, Size>{
  'small phone': Size(320, 640),
  'large phone': Size(430, 932),
  'tablet portrait': Size(820, 1180),
  'tablet landscape': Size(1280, 800),
};

void main() {
  final content = contentFrom(freshRaw());

  group('every piece of content has original artwork', () {
    test('rooms, hotspots, items, characters, endings and sigils', () {
      for (final r in content.rooms) {
        expect(RoomArt.supported, contains(r.sceneId), reason: r.id);
      }
      for (final h in content.allHotspots) {
        expect(HotspotArt.supported, contains(h.id), reason: h.id);
      }
      for (final i in content.items) {
        expect(ItemIcon.supported, contains(i.iconId), reason: i.id);
      }
      for (final c in content.story.characters) {
        expect(CharacterPortrait.supported, contains(c.id), reason: c.id);
      }
      for (final e in content.story.endings) {
        expect(EndingScene.supported, contains(e.sceneId), reason: e.id);
      }
      for (final p in content.puzzles.where(
        (p) => p.config['options'] != null,
      )) {
        for (final o in (p.config['options'] as List).cast<String>()) {
          expect(Sigils.supported, contains(o), reason: '${p.id} $o');
        }
      }
    });

    test('every room scene is visually distinct', () {
      final arts = content.rooms
          .map((r) => RoomArt.forScene(r.sceneId))
          .toList();
      final signatures = arts
          .map((a) => '${a.runtimeType}|${a.topColor}|${a.bottomColor}')
          .toSet();
      expect(signatures, hasLength(content.rooms.length));
    });
  });

  group('full motion renders without errors', () {
    // These run with animation ON to exercise every painter and controller.
    testWidgets('every room, with markers, on a phone', (tester) async {
      setScreen(tester, 390, 844);
      final services = await makeServices(
        settings: const AppSettings(),
        reveal: true,
      );
      await bootApp(tester, services);
      await openScreen(tester, const RoomScreen());
      for (final room in content.rooms) {
        services.preview.moveTo(room.id);
        // Several frames across the animation loop.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 450));
        }
        expect(tester.takeException(), isNull, reason: room.id);
        expect(find.text(room.name), findsWidgets);
      }
    });

    testWidgets('every ending and every portrait', (tester) async {
      setScreen(tester, 390, 844);
      final services = await makeServices(
        settings: const AppSettings(),
        reveal: true,
      );
      await bootApp(tester, services);
      for (final e in content.story.endings) {
        await openScreen(tester, EndingScreen(endingId: e.id));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull, reason: e.id);
        Navigator.of(tester.element(find.byType(EndingScreen))).pop();
        await settle(tester);
      }
      for (final c in content.choices) {
        await openScreen(tester, DialogueScreen(choiceId: c.id));
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull, reason: c.id);
        Navigator.of(tester.element(find.byType(DialogueScreen))).pop();
        await settle(tester);
      }
    });

    testWidgets('every puzzle with animation on', (tester) async {
      setScreen(tester, 390, 844);
      final services = await makeServices(
        settings: const AppSettings(),
        reveal: true,
      );
      await bootApp(tester, services);
      for (final p in content.puzzles) {
        await openScreen(tester, PuzzleScreen(puzzleId: p.id));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: p.id);
        Navigator.of(tester.element(find.byType(PuzzleScreen))).pop();
        await settle(tester);
      }
    });
  });

  group('layouts fit every screen size without overflow', () {
    final screens = <String, Widget Function()>{
      'room': () => const RoomScreen(),
      'inventory': () => const InventoryScreen(),
      'journal': () => const JournalScreen(),
      'settings': () => const SettingsScreen(),
      'saves': () => const SaveSlotsScreen(),
      'dialogue': () => const DialogueScreen(choiceId: 'c_echo_fate'),
      'ending': () => const EndingScreen(endingId: 'homecoming'),
      'gears puzzle': () => const PuzzleScreen(puzzleId: 'p8_gear_alignment'),
      'clock puzzle': () => const PuzzleScreen(puzzleId: 'p7_stopped_hands'),
      'cipher puzzle': () => const PuzzleScreen(puzzleId: 'p3_shelf_cipher'),
    };

    for (final size in _sizes.entries) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('${size.key} at ${(textScale * 100).round()}% text', (
          tester,
        ) async {
          setScreen(tester, size.value.width, size.value.height);
          final services = await makeServices(
            settings: AppSettings(reducedMotion: true, textScale: textScale),
            reveal: true,
          );
          await bootApp(tester, services);
          expect(tester.takeException(), isNull, reason: 'menu');
          for (final s in screens.entries) {
            await openScreen(tester, s.value());
            expect(tester.takeException(), isNull, reason: s.key);
            Navigator.of(
              tester.element(
                find.byWidget(tester.widget(find.byType(Navigator))).first,
              ),
            ).popUntil((r) => r.isFirst);
            await settle(tester, 500);
          }
        });
      }
    }

    testWidgets('room uses a side panel on a landscape tablet', (tester) async {
      setScreen(tester, 1280, 800);
      final services = await makeServices();
      await bootApp(tester, services);
      await openScreen(tester, const RoomScreen());
      final description = tester.getTopLeft(
        find.text(
          services.preview.currentRoom.description.resolve(services.preview),
        ),
      );
      expect(
        description.dx,
        greaterThan(800),
        reason: 'description should sit in the right-hand panel',
      );
    });
  });

  group('accessibility', () {
    testWidgets(
      'room objects are labeled, sized for touch, and meet guidelines',
      (tester) async {
        setScreen(tester, 390, 844);
        final handle = tester.ensureSemantics();
        final services = await makeServices();
        await bootApp(tester, services);
        await openScreen(tester, const RoomScreen());

        for (final h in services.preview.currentRoom.hotspots) {
          final box = tester.getSize(find.byKey(ValueKey(h.id)));
          expect(box.width, greaterThanOrEqualTo(48), reason: h.id);
          expect(box.height, greaterThanOrEqualTo(48), reason: h.id);
          expect(
            find.bySemanticsLabel(h.semanticLabel),
            findsOneWidget,
            reason: h.id,
          );
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      },
    );

    testWidgets(
      'menu, settings and puzzle screens meet tap-target guidelines',
      (tester) async {
        setScreen(tester, 390, 844);
        final handle = tester.ensureSemantics();
        await bootApp(tester, await makeServices(reveal: true));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        for (final screen in const [
          SettingsScreen(),
          PuzzleScreen(puzzleId: 'p5_resonance_tuner'),
          PuzzleScreen(puzzleId: 'p1_candle_moons'),
        ]) {
          await openScreen(tester, screen);
          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
            reason: '$screen',
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
            reason: '$screen',
          );
          Navigator.of(tester.element(find.byWidget(screen))).pop();
          await settle(tester);
        }
        handle.dispose();
      },
    );

    testWidgets('list mode exposes every object as a button', (tester) async {
      setScreen(tester, 390, 844);
      final services = await makeServices(
        settings: const AppSettings(reducedMotion: true, roomListMode: true),
      );
      await bootApp(tester, services);
      await openScreen(tester, const RoomScreen());
      for (final h in services.preview.currentRoom.hotspots) {
        await tester.dragUntilVisible(
          find.text(h.label),
          find.byType(SingleChildScrollView).last,
          const Offset(0, -120),
        );
        expect(find.text(h.label), findsOneWidget, reason: h.id);
      }
    });

    testWidgets('text contrast meets WCAG AA on the default palette', (
      tester,
    ) async {
      // Text colors against the darkest and lightest panel surfaces.
      const pairs = {
        'parchment on navy': (Color(0xFFEDE6D3), Color(0xFF0A1030)),
        'parchment on deepNavy': (Color(0xFFEDE6D3), Color(0xFF111A45)),
        'parchment on deepPurple': (Color(0xFFEDE6D3), Color(0xFF2B1357)),
        'fog on navy': (Color(0xFFA9B0CF), Color(0xFF0A1030)),
        'fog on deepPurple': (Color(0xFFA9B0CF), Color(0xFF2B1357)),
        'gold light on deepPurple': (Color(0xFFF0D78C), Color(0xFF2B1357)),
        'cyan on midnight': (Color(0xFF8DEBF5), Color(0xFF050818)),
        'wood on paper (evidence)': (Color(0xFF2A1B14), Color(0xFFD9CDAE)),
        'danger on navy': (Color(0xFFFF7A8A), Color(0xFF0A1030)),
      };
      for (final e in pairs.entries) {
        expect(
          _contrast(e.value.$1, e.value.$2),
          greaterThanOrEqualTo(4.5),
          reason: e.key,
        );
      }
      // High contrast mode: white on black.
      expect(_contrast(Colors.white, Colors.black), greaterThanOrEqualTo(7));
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
