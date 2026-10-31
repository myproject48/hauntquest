import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/app/app_services.dart';
import 'package:hauntquest/app/game_store.dart';
import 'package:hauntquest/content/definitions/puzzle_def.dart';
import 'package:hauntquest/domain/engine/game_engine.dart';
import 'package:hauntquest/domain/puzzles/puzzle_evaluator.dart';
import 'package:hauntquest/features/puzzle/puzzle_screen.dart';

import '../content/content_fixture.dart';
import '../domain/complete_puzzle_system_test.dart' show solutionFor;
import 'ui_harness.dart';

void main() {
  final content = contentFrom(freshRaw());
  final puzzles = content.puzzles.where(
    (p) => p.config['variant'] != null || p.kind == PuzzleKind.clock,
  );
  Future<AppServices> ready(String id) async {
    final p = content.puzzleById(id)!;
    return AppServices.create(
      content: content,
      store: MemorySettingsStore(),
      gameStore: MemoryGameStore(
        GameEngine(content).newGame().copyWith(
          currentRoomId: p.roomId,
          inventory: content.items.map((i) => i.id).toList(),
          acquiredItemIds: content.items.map((i) => i.id).toSet(),
          solvedPuzzleIds: content.puzzles
              .where((v) => v.id != id)
              .map((v) => v.id)
              .toSet(),
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.dragUntilVisible(
        f,
        find.byType(ListView).last,
        const Offset(0, -180),
      );
    }
    await t.ensureVisible(f);
    await settle(t, 200);
    await t.tap(f);
    await settle(t, 200);
  }

  for (final p in puzzles) {
    testWidgets(
      '${p.title}: wrong answer, reset, playable solution, solved reopening',
      (t) async {
        setScreen(t, 430, 932);
        final services = await ready(p.id);
        await bootApp(t, services);
        await openScreen(t, PuzzleScreen(puzzleId: p.id));
        await tap(t, find.text('CHECK'));
        expect(services.game.puzzleSolved(p.id), isFalse);
        expect(services.game.state.puzzleAttempts[p.id], 1);
        await tap(t, find.text('RESET'));
        final answer = solutionFor(p);
        switch (answer) {
          case CipherInput(:final text):
            await t.ensureVisible(find.byType(TextFormField));
            await t.enterText(find.byType(TextFormField), text);
            t.testTextInput.hide();
            await settle(t);
          case SequenceInput(:final picks):
            for (final pick in picks) {
              await tap(t, find.byKey(ValueKey('pick-$pick')));
            }
          case GearsInput(:final positions):
            if (p.config['variant'] == 'mirror') {
              for (var i = 0; i < positions.length; i++) {
                if (positions[i] == 1) {
                  await tap(t, find.byKey(ValueKey('mirror-$i')));
                }
              }
            } else {
              for (var i = 0; i < positions.length; i++) {
                for (var n = 0; n < positions[i]; n++) {
                  await tap(t, find.byKey(ValueKey('disc-$i')));
                }
              }
            }
          case ClockInput():
            await tap(t, find.bySemanticsLabel('Hour back one'));
            for (var n = 0; n < 4; n++) {
              await tap(t, find.bySemanticsLabel('Minutes back five'));
            }
          default:
            fail('Missing UI solution driver for ${p.id}');
        }
        expect(
          services.game.puzzleSolved(p.id),
          isFalse,
          reason: 'Correct draft must wait for Check',
        );
        await tap(t, find.text('CHECK'));
        expect(services.game.puzzleSolved(p.id), isTrue);
        expect(find.text('That is right'), findsOneWidget);
        Navigator.of(t.element(find.byType(PuzzleScreen))).pop();
        await settle(t);
        await openScreen(t, PuzzleScreen(puzzleId: p.id));
        expect(find.text('CHECK'), findsNothing);
        expect(find.text(p.successText), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unfinished inputs, hints and reset survive closing and restarting',
    (t) async {
      setScreen(t, 430, 932);
      final services = await ready('p12_rune_gaps');
      await bootApp(t, services);
      await openScreen(t, const PuzzleScreen(puzzleId: 'p12_rune_gaps'));
      await tap(t, find.byKey(const ValueKey('pick-II')));
      await tap(t, find.text('I NEED A HINT'));
      Navigator.of(t.element(find.byType(PuzzleScreen))).pop();
      await settle(t);
      final loaded = await services.game.store!.load();
      final restarted = await AppServices.create(
        content: content,
        store: MemorySettingsStore(),
        gameStore: MemoryGameStore(loaded),
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      await bootApp(t, restarted);
      await openScreen(t, const PuzzleScreen(puzzleId: 'p12_rune_gaps'));
      expect(find.text('1. II'), findsOneWidget);
      expect(restarted.game.state.puzzleProgress['p12_rune_gaps']!.hintTier, 1);
      await tap(t, find.text('RESET'));
      expect(
        (restarted.game.state.puzzleProgress['p12_rune_gaps']!.input
                as SequenceInput)
            .picks,
        isEmpty,
      );
      expect(restarted.game.state.puzzleProgress['p12_rune_gaps']!.hintTier, 1);
      expect(restarted.game.state.puzzleAttempts['p12_rune_gaps'], isNull);
    },
  );

  testWidgets(
    'echo replay shows the clue pulses without entering or solving the answer',
    (t) async {
      setScreen(t, 430, 932);
      final services = await ready('p16_echo_frequencies');
      await bootApp(t, services);
      await openScreen(t, const PuzzleScreen(puzzleId: 'p16_echo_frequencies'));
      await tap(t, find.text('Replay the call'));
      expect(find.text('Pulse 1: 220 Hz'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 800));
      expect(find.text('Pulse 2: 440 Hz'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 800));
      expect(find.text('Pulse 3: 330 Hz'), findsOneWidget);
      expect(
        services.game.state.puzzleProgress['p16_echo_frequencies'],
        isNull,
      );
      expect(services.game.puzzleSolved('p16_echo_frequencies'), isFalse);
      Navigator.of(t.element(find.byType(PuzzleScreen))).pop();
      await settle(t);
      expect(t.takeException(), isNull);
    },
  );
}
