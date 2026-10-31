import 'package:flutter_test/flutter_test.dart';

import '../../tool/hooks/checks.dart';

void main() {
  group('hook input', () {
    test('reads the path from file events and agent tool events', () {
      expect(changedPath({'file_path': '/w/lib/a.dart'}), '/w/lib/a.dart');
      expect(
        changedPath({
          'tool_input': {'path': 'lib/b.dart'},
        }),
        'lib/b.dart',
      );
      expect(
        changedPath({
          'tool_input': {'command': 'ls'},
        }),
        isNull,
      );
      expect(relativeTo('/w', '/w/lib/a.dart'), 'lib/a.dart');
      expect(relativeTo('/w', 'lib/a.dart'), 'lib/a.dart');
    });

    test('normalizes paths so ./ and .. cannot bypass the guards', () {
      expect(relativeTo('/w', './.gitignore'), '.gitignore');
      expect(relativeTo('/w', '/w/./.gitignore'), '.gitignore');
      expect(relativeTo('/w', '/w/lib/../.gitignore'), '.gitignore');
      expect(relativeTo('/w/', '/w//lib//a.dart'), 'lib/a.dart');
      expect(relativeTo('/w', '/other/.gitignore'), '/other/.gitignore');
      expect(relativeTo('/w', '/w/../w2/.gitignore'), '/w2/.gitignore');
    });

    test('classifies ignore files that can hide .kiro', () {
      expect(ignoreFileKind('.gitignore'), 'root');
      expect(ignoreFileKind('.git/info/exclude'), 'root');
      expect(ignoreFileKind('.kiro/.gitignore'), 'kiro');
      expect(ignoreFileKind('.kiro/hooks/.gitignore'), 'kiro');
      expect(ignoreFileKind('android/.gitignore'), isNull);
      expect(ignoreFileKind('lib/a.dart'), isNull);
      expect(activeIgnoreRules('# note\n\n!keep\n*\n'), ['*']);
    });
  });

  group('dart classification', () {
    test('checks hand-written sources, skips generated and build output', () {
      expect(isCheckedDartFile('lib/domain/engine/game_engine.dart'), isTrue);
      expect(isCheckedDartFile('test/domain/game_engine_test.dart'), isTrue);
      expect(isCheckedDartFile('lib/x.g.dart'), isFalse);
      expect(isCheckedDartFile('build/app/x.dart'), isFalse);
      expect(isCheckedDartFile('.dart_tool/x.dart'), isFalse);
      expect(isCheckedDartFile('lib/x.txt'), isFalse);
    });

    test('important code gets analysis; game logic suggests focused tests', () {
      expect(isImportantCode('lib/domain/models/game_state.dart'), isTrue);
      expect(
        isImportantCode('lib/features/menu/main_menu_screen.dart'),
        isFalse,
      );
      expect(
        suggestedTests('lib/domain/engine/game_engine.dart'),
        'flutter test test/domain',
      );
      expect(
        suggestedTests('assets/content/puzzles.json'),
        'flutter test test/content',
      );
      expect(
        suggestedTests('lib/features/room/room_screen.dart'),
        contains('exploration_test'),
      );
      expect(suggestedTests('lib/core/theme/app_colors.dart'), isNull);
    });
  });

  group('.gitignore guard', () {
    const good =
        '.dart_tool/\n/build/\n.flutter-plugins-dependencies\n/coverage/\n';

    test('accepts a file that ignores artifacts and keeps .kiro', () {
      expect(checkGitignore(good), isEmpty);
    });

    test('flags every way of ignoring .kiro', () {
      for (final rule in [
        '.kiro',
        '.kiro/',
        '/.kiro/',
        '.kiro/*',
        '**/.kiro',
        '.kiro/steering',
        '.*',
      ]) {
        final f = checkGitignore('$good$rule\n');
        expect(f.any((x) => x.message.contains('.kiro')), isTrue, reason: rule);
      }
    });

    test('a later negation re-includes .kiro', () {
      expect(checkGitignore('$good.*\n!.kiro/\n'), isEmpty);
    });

    test('ignores comments that mention .kiro', () {
      expect(
        checkGitignore('$good# .kiro/ is intentionally NOT ignored.\n'),
        isEmpty,
      );
    });

    test('flags missing build artifact rules', () {
      final f = checkGitignore('.dart_tool/\n');
      expect(f.map((x) => x.message).join(), contains('build output'));
    });

    test('computes the text an agent edit would produce', () {
      expect(proposedText('fs_write', {'text': 'a'}, 'old'), 'a');
      expect(proposedText('fs_append', {'text': '.kiro/'}, 'x\n'), 'x\n.kiro/');
      expect(
        proposedText('str_replace', {'oldStr': 'x', 'newStr': '.kiro'}, 'x\ny'),
        '.kiro\ny',
      );
      expect(proposedText('delete_file', const {}, ''), isNull);
    });
  });

  group('shell command classification', () {
    test('finds commit and push inside chains', () {
      expect(gitActionOf('flutter test'), GitAction.none);
      expect(gitActionOf('git status'), GitAction.none);
      expect(
        gitActionOf('git add a.dart && git commit -m "x"'),
        GitAction.commit,
      );
      expect(gitActionOf('git -C repo commit -m x'), GitAction.commit);
      expect(
        gitActionOf('git commit -m x && git push -u origin b'),
        GitAction.push,
      );
      expect(gitActionOf('echo "git commit is a phrase"'), GitAction.none);
    });

    test('knows when a command stages files itself', () {
      expect(stagesFiles('git commit -m x'), isFalse);
      expect(stagesFiles('git commit -am x'), isTrue);
      expect(stagesFiles('git add . && git commit -m x'), isTrue);
    });
  });

  group('artifacts and secrets', () {
    test('forbids build output, caches, keys and env files', () {
      expect(forbiddenPathReason('build/app/outputs/app.apk'), isNotNull);
      expect(forbiddenPathReason('.dart_tool/package_config.json'), isNotNull);
      expect(forbiddenPathReason('android/local.properties'), isNotNull);
      expect(forbiddenPathReason('android/app/upload.jks'), isNotNull);
      expect(forbiddenPathReason('.env'), isNotNull);
      expect(forbiddenPathReason('lib/main.dart'), isNull);
      expect(forbiddenPathReason('.kiro/hooks/x.json'), isNull);
    });

    test('detects obvious secrets and masks them', () {
      // Built at runtime so this test file itself contains no secret pattern.
      final aws = 'AKIA${'Q' * 16}';
      final f = scanForSecrets('a.dart', 'const k = "$aws";');
      expect(f.single.message, contains('AWS'));
      expect(
        f.single.toString(),
        isNot(contains(aws)),
        reason: 'never print the secret',
      );
      expect(
        scanForSecrets('b.txt', '-----BEGIN ${'PRIVATE'} KEY-----'),
        hasLength(1),
      );
      expect(scanForSecrets('c.dart', "apiKey = '${'z' * 24}'"), hasLength(1));
    });

    test('ignores placeholders and explicitly allowed lines', () {
      expect(
        scanForSecrets('a', "apiKey = 'your_api_key_goes_here_please'"),
        isEmpty,
      );
      expect(
        scanForSecrets('a', "token: '\${AI_KEY_FROM_DART_DEFINE}'"),
        isEmpty,
      );
      final aws = 'AKIA${'Q' * 16}';
      expect(scanForSecrets('a', '"$aws" // kiro-allow-secret'), isEmpty);
      expect(
        scanForSecrets('a', 'final passwordField = TextField();'),
        isEmpty,
      );
    });
  });
}
