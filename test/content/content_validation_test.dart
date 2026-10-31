import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hauntquest/content/content_loader.dart';
import 'package:hauntquest/content/validation/progression_simulator.dart';

import 'content_fixture.dart';

void main() {
  final content = contentFrom(freshRaw());
  final report = validateRaw(freshRaw());

  group('The Whispering Manor content', () {
    test('passes full validation with no errors or warnings', () {
      expect(report.issues, isEmpty, reason: report.describe());
      expect(report.isValid, isTrue);
    });

    test('has the planned shape', () {
      expect(content.story.title, 'The Whispering Manor');
      expect(content.rooms.map((r) => r.name), [
        'Moonlit Entrance Hall',
        'Forgotten Library',
        "Alchemist's Workshop",
        'Clocktower Chamber',
        'The Echo Vault',
      ]);
      expect(content.items, hasLength(10));
      expect(content.puzzles.length, greaterThanOrEqualTo(8));
      expect(content.story.characters.length, greaterThanOrEqualTo(4));
      expect(content.story.endings, hasLength(3));
      expect(content.choices.length, greaterThanOrEqualTo(3));
    });

    test(
      'every room has at least three hotspots and every puzzle three hints',
      () {
        for (final room in content.rooms) {
          expect(
            room.hotspots.length,
            greaterThanOrEqualTo(3),
            reason: room.id,
          );
        }
        for (final puzzle in content.puzzles) {
          expect(puzzle.hints, hasLength(3), reason: puzzle.id);
        }
      },
    );

    test('loads through ContentLoader from a file reader', () async {
      final loaded = await ContentLoader.load(
        (path) => File(path).readAsString(),
      );
      expect(loaded.rooms, hasLength(5));
      expect(loaded.puzzles, hasLength(content.puzzles.length));
    });

    test('all asset files are registered in pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/content/'));
    });
  });

  group('Progression', () {
    test('reaches every room, item, hotspot and mandatory puzzle', () {
      final sim = ProgressionSimulator(content);
      expect(sim.run(), isEmpty);
      for (final leaf in sim.leaves) {
        expect(leaf.state.visited, content.rooms.map((r) => r.id).toSet());
        expect(
          leaf.state.solved,
          content.puzzles.where((p) => p.mandatory).map((p) => p.id).toSet(),
        );
      }
    });

    test('no valid choice combination leads to a dead end', () {
      final sim = ProgressionSimulator(content)..run();
      expect(sim.leaves, isNotEmpty);
      expect(sim.leaves.every((l) => l.endingId != null), isTrue);
    });

    test('all three endings are reachable with documented routes', () {
      final routes = {for (final r in report.endingRoutes) r.endingId: r};
      expect(routes.keys.toSet(), {
        'release_echo',
        'echo_guardian',
        'seal_echo',
      });
      expect(routes['release_echo']!.options.last, 'ef_release');
      expect(routes['echo_guardian']!.options.last, 'ef_guardian');
      expect(routes['seal_echo']!.options.last, 'ef_seal');
    });

    test('Release is always available, so completion is never blocked', () {
      final sim = ProgressionSimulator(content)..run();
      for (final leaf in sim.leaves) {
        // Every playthrough could have chosen to release the Echo.
        final choice = content.choiceById('c_echo_fate')!;
        final release = choice.options.firstWhere((o) => o.id == 'ef_release');
        expect(release.enabledWhen, isNull);
        expect(leaf.endingId, isNotNull);
      }
    });

    test(
      'Guardianship is attainable without choosing the optional truth question',
      () {
        final home = report.endingRoutes.firstWhere(
          (r) => r.endingId == 'echo_guardian',
        );
        expect(home.leafCount, greaterThan(0));
        // Discoveries supply the truth requirement; the optional Tallow question is not required.
        final sim = ProgressionSimulator(content)..run();
        final withoutAsk = sim.leaves.where(
          (l) => l.endingId == 'echo_guardian' && !l.options.contains('tw_ask'),
        );
        expect(withoutAsk, isNotEmpty);
      },
    );

    test('flags stay inside their declared ranges in every playthrough', () {
      final sim = ProgressionSimulator(content)..run();
      for (final leaf in sim.leaves) {
        for (final flag in content.story.flags) {
          final value = leaf.state.flag(flag.id);
          expect(value, inInclusiveRange(flag.min, flag.max), reason: flag.id);
        }
      }
    });

    test('a valid solve order exists covering all mandatory puzzles', () {
      expect(
        report.dependencyOrder.toSet(),
        content.puzzles.where((p) => p.mandatory).map((p) => p.id).toSet(),
      );
    });
  });

  group('Ending resolver', () {
    test('is total and deterministic over every flag combination', () {
      for (var fate = 0; fate <= 3; fate++) {
        for (var truth = 0; truth <= 5; truth++) {
          for (var mercy = 0; mercy <= 3; mercy++) {
            for (var bargain = 0; bargain <= 1; bargain++) {
              final s = ProgressionSimulator(content).initialState()
                ..flags['fate'] = fate
                ..flags['truthFragments'] = truth
                ..flags['mercy'] = mercy
                ..flags['acceptedBargain'] = bargain;
              final first = content.resolveEnding(s);
              expect(first, isNotNull);
              expect(content.endingById(first!), isNotNull);
              expect(content.resolveEnding(s), first);
            }
          }
        }
      }
    });
  });
}
