// Entry point for the Kiro agent hooks in .kiro/hooks/. Reads the hook event
// JSON from stdin and runs one read-only check. It never edits source files,
// never stages, commits or pushes, and never deletes anything, so a hook
// cannot trigger itself again.
//
//   dart tool/hooks/kiro_hook.dart post-edit   # after a save or agent edit
//   dart tool/hooks/kiro_hook.dart pre-write   # before an agent file write
//   dart tool/hooks/kiro_hook.dart pre-bash    # before an agent shell command
//   dart tool/hooks/kiro_hook.dart scan        # manual: secrets + .gitignore
//
// Exit codes follow Kiro's hook contract: 0 = fine, 2 = block the action
// (only meaningful for PreToolUse), 1 = problems found, nothing blocked.
import 'dart:convert';
import 'dart:io';

import 'checks.dart';

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? '' : args.first;
  final raw = mode == 'scan' ? '' : await stdin.transform(utf8.decoder).join();
  final event = _decode(raw);
  final root = Directory.current.path;

  final code = switch (mode) {
    'post-edit' => await _postEdit(event, root),
    'pre-write' => _preWrite(event, root),
    'pre-bash' => await _preBash(event, root),
    'scan' => await _scan(root),
    _ => _usage(),
  };
  exit(code);
}

Map<String, Object?> _decode(String raw) {
  if (raw.trim().isEmpty) return const {};
  try {
    final v = jsonDecode(raw);
    return v is Map ? v.cast<String, Object?>() : const {};
  } on FormatException {
    stderr.writeln('kiro_hook: could not read the hook event JSON.');
    return const {};
  }
}

int _usage() {
  stderr.writeln(
    'usage: dart tool/hooks/kiro_hook.dart post-edit|pre-write|pre-bash|scan',
  );
  return 64;
}

Future<ProcessResult> _run(String exe, List<String> args) =>
    Process.run(exe, args, runInShell: Platform.isWindows);

// -------------------------------------------------------------- post-edit

Future<int> _postEdit(Map<String, Object?> event, String root) async {
  final path = changedPath(event);
  if (path == null) return 0;
  final rel = relativeTo(root, path);

  if (rel == '.gitignore') return _reportGitignore(root);

  final tests = suggestedTests(rel);
  if (!isCheckedDartFile(rel)) {
    if (tests != null) {
      stdout.writeln('Content changed: $rel. Focused check: $tests');
    }
    return 0;
  }
  if (!File(path).existsSync() && !File('$root/$rel').existsSync()) return 0;

  var problems = 0;
  stdout.writeln('Checking $rel');

  // Check only: --output=none never rewrites the file, so this hook cannot
  // cause another save event.
  final fmt = await _run('dart', [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    rel,
  ]);
  if (fmt.exitCode == 0) {
    stdout.writeln('  format: ok');
  } else {
    problems++;
    stdout.writeln('  format: needs formatting. Run: dart format $rel');
  }

  if (isImportantCode(rel)) {
    final an = await _run('dart', ['analyze', '--fatal-infos', rel]);
    if (an.exitCode == 0) {
      stdout.writeln('  analyze: no issues');
    } else {
      problems++;
      final issues = '${an.stdout}'
          .split('\n')
          .where((l) => RegExp(r'^\s*(error|warning|info) •').hasMatch(l))
          .take(10);
      stdout.writeln('  analyze: issues found');
      for (final l in issues) {
        stdout.writeln('    ${l.trim()}');
      }
    }
  }

  if (tests != null) {
    stdout.writeln(
      '  tests: game logic changed. Run the focused tests before moving on: $tests',
    );
  }
  return problems == 0 ? 0 : 1;
}

Future<int> _reportGitignore(String root) async {
  final file = File('$root/.gitignore');
  final findings = file.existsSync()
      ? checkGitignore(file.readAsStringSync())
      : [const Finding('.gitignore', 'file is missing.')];
  findings.addAll(await _gitKiroIgnored(root));
  if (findings.isEmpty) {
    stdout.writeln(
      '.gitignore: build artifacts are ignored and .kiro/ is tracked.',
    );
    return 0;
  }
  for (final f in findings) {
    stdout.writeln(f);
  }
  return 1;
}

/// Asks Git itself, when this is a repository, whether .kiro would be ignored
/// by any rule (including global excludes and nested .gitignore files).
Future<List<Finding>> _gitKiroIgnored(String root) async {
  if (!await _isGitRepo()) return const [];
  final probe = await _run('git', [
    'check-ignore',
    '-v',
    '--no-index',
    '.kiro/steering/product.md',
  ]);
  if (probe.exitCode == 0) {
    return [
      Finding(
        '.kiro',
        'Git would ignore .kiro/ because of: ${'${probe.stdout}'.trim()}',
      ),
    ];
  }
  // Nested ignore files (for example .kiro/hooks/.gitignore) can hide single
  // files without matching the probe above, so also list every ignored file.
  final hidden = await _gitList([
    'ls-files',
    '--others',
    '--ignored',
    '--exclude-standard',
    '--',
    '.kiro',
  ]);
  return [
    for (final f in hidden.take(10))
      Finding(
        f,
        'is inside .kiro/ but ignored by Git; it would not be committed.',
      ),
  ];
}

Future<bool> _isGitRepo() async {
  final r = await _run('git', ['rev-parse', '--is-inside-work-tree']);
  return r.exitCode == 0 && '${r.stdout}'.trim() == 'true';
}

// -------------------------------------------------------------- pre-write

int _preWrite(Map<String, Object?> event, String root) {
  final path = changedPath(event);
  if (path == null) return 0;
  final rel = relativeTo(root, path);
  final kind = ignoreFileKind(rel);
  if (kind == null) return 0;

  final tool = event['tool_name'] is String ? event['tool_name'] as String : '';
  final rawInput = event['tool_input'];
  final input = rawInput is Map
      ? rawInput.cast<String, Object?>()
      : const <String, Object?>{};
  final file = File('$root/$rel');
  final current = file.existsSync() ? file.readAsStringSync() : '';
  final next = proposedText(tool, input, current);
  if (next == null) return 0;

  final problems = kind == 'root'
      ? checkGitignore(
          next,
          path: rel,
        ).where((f) => f.message.contains('.kiro')).map((f) => '$f').toList()
      : [
          for (final r in activeIgnoreRules(next))
            '$rel: rule "$r" would hide files inside .kiro/ from Git.',
        ];
  if (problems.isEmpty) return 0;
  // Exit 2 blocks the write; stderr is shown to the agent.
  stderr.writeln('Blocked: this change to $rel would exclude .kiro/ from Git.');
  for (final p in problems) {
    stderr.writeln('  $p');
  }
  stderr.writeln(
    'The .kiro directory holds the project specs, steering and hooks and must stay tracked.',
  );
  return 2;
}

// --------------------------------------------------------------- pre-bash

Future<int> _preBash(Map<String, Object?> event, String root) async {
  final input = (event['tool_input'] as Map? ?? const {})
      .cast<String, Object?>();
  final command = input['command'] as String? ?? '';
  switch (gitActionOf(command)) {
    case GitAction.none:
      return 0;
    case GitAction.push:
      // Never pushed automatically: ask the user every time.
      stdout.writeln(
        jsonEncode({
          'hookSpecificOutput': {
            'permissionDecision': 'ask',
            'permissionDecisionReason': 'The agent wants to run git push. Pushing is never automatic in this project; confirm the branch and remote first.',
          },
        }),
      );
      return 0;
    case GitAction.commit:
      break;
  }

  if (!await _isGitRepo()) return 0;
  final files = <String>{
    ...await _gitList([
      'diff',
      '--cached',
      '--name-only',
      '--diff-filter=ACMR',
    ]),
    if (stagesFiles(command))
      ...await _gitList(['diff', '--name-only', '--diff-filter=ACMR']),
    if (stagesFiles(command))
      ...await _gitList(['ls-files', '--others', '--exclude-standard']),
  };
  final findings = <Finding>[
    for (final f in files)
      if (forbiddenPathReason(f) case final reason?)
        Finding(f, 'should not be committed ($reason)'),
    ...await _gitKiroIgnored(root),
    for (final f in files) ..._scanFile(root, f),
  ];
  if (findings.isEmpty) return 0;

  stderr.writeln('Blocked: the commit would include files that look unsafe.');
  for (final f in findings.take(30)) {
    stderr.writeln('  $f');
  }
  stderr.writeln(
    'Unstage them (git restore --staged <file>) or remove the secret. '
    'For a deliberate false positive, add the comment "kiro-allow-secret" on that line.',
  );
  return 2;
}

Future<List<String>> _gitList(List<String> args) async {
  final r = await _run('git', args);
  if (r.exitCode != 0) return const [];
  return '${r.stdout}'
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

List<Finding> _scanFile(String root, String rel) {
  final file = File('$root/$rel');
  if (!file.existsSync()) return const [];
  final len = file.lengthSync();
  if (len == 0 || len > 1024 * 1024) return const [];
  final bytes = file.readAsBytesSync();
  if (bytes.take(8000).contains(0)) return const []; // binary
  return scanForSecrets(rel, utf8.decode(bytes, allowMalformed: true));
}

// ------------------------------------------------------------------ scan

/// Manual pre-commit check of the whole working tree (works without Git).
Future<int> _scan(String root) async {
  final files = await _isGitRepo()
      ? <String>{
          ...await _gitList(['ls-files']),
          ...await _gitList(['ls-files', '--others', '--exclude-standard']),
        }
      : _walk(root);
  final findings = <Finding>[for (final f in files) ..._scanFile(root, f)];
  stdout.writeln('Scanned ${files.length} files for secrets.');
  final gitignore = File('$root/.gitignore');
  final ignoreFindings = gitignore.existsSync()
      ? checkGitignore(gitignore.readAsStringSync())
      : [const Finding('.gitignore', 'file is missing.')];
  findings
    ..addAll(ignoreFindings)
    ..addAll(await _gitKiroIgnored(root));
  if (findings.isEmpty) {
    stdout.writeln(
      'No secrets found. .gitignore keeps build artifacts out and .kiro/ in.',
    );
    return 0;
  }
  for (final f in findings) {
    stdout.writeln(f);
  }
  return 1;
}

/// Source files when there is no Git repository yet: everything except
/// build output, caches and IDE folders.
Set<String> _walk(String root) {
  const skip = {
    'build',
    '.dart_tool',
    '.idea',
    '.gradle',
    'Pods',
    '.git',
    'ephemeral',
  };
  final out = <String>{};
  void visit(Directory d) {
    for (final e in d.listSync(followLinks: false)) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (e is Directory) {
        if (!skip.contains(name)) visit(e);
      } else if (e is File) {
        out.add(relativeTo(root, e.path));
      }
    }
  }

  visit(Directory(root));
  return out;
}
