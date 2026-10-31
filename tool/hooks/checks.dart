// Pure check logic shared by the Kiro hook scripts. No I/O here, so it can be
// unit-tested (see test/tool/hook_checks_test.dart).

/// One problem found by a check.
class Finding {
  const Finding(this.path, this.message, {this.line});

  final String path;
  final String message;
  final int? line;

  @override
  String toString() =>
      line == null ? '$path: $message' : '$path:$line: $message';
}

// ------------------------------------------------------------ hook input

/// The file a hook event is about: `file_path` for file events, or
/// `tool_input.path` for agent write tools. Null if there is none.
String? changedPath(Map<String, Object?> event) {
  final direct = event['file_path'];
  if (direct is String && direct.isNotEmpty) return direct;
  final input = event['tool_input'];
  if (input is Map) {
    for (final key in const ['path', 'file_path', 'targetFile']) {
      final v = input[key];
      if (v is String && v.isNotEmpty) return v;
    }
  }
  return null;
}

/// Converts a path (absolute, or relative to [root]) to a normalized
/// project-relative path. `./`, `..` and repeated slashes are resolved first,
/// so `./.gitignore` and `lib/../.gitignore` both become `.gitignore`.
/// Paths outside [root] are returned normalized and absolute.
String relativeTo(String root, String path) {
  final r = _normalize(root);
  final p = _normalize(path.startsWith('/') ? path : '$r/$path');
  final prefix = r.endsWith('/') ? r : '$r/';
  return p.startsWith(prefix) ? p.substring(prefix.length) : p;
}

String _normalize(String path) {
  final out = <String>[];
  for (final s in path.split('/')) {
    if (s.isEmpty || s == '.') continue;
    if (s == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(s);
    }
  }
  final joined = out.join('/');
  return path.startsWith('/') ? '/$joined' : joined;
}

/// Which kind of Git ignore file [rel] is, from the point of view of the
/// `.kiro` guard: `root` for the files whose rules apply to the whole
/// repository, `kiro` for an ignore file inside `.kiro/` (any active rule
/// there hides part of `.kiro`), or null for files the guard ignores.
String? ignoreFileKind(String rel) {
  if (rel == '.gitignore' || rel == '.git/info/exclude') return 'root';
  if (rel.startsWith('.kiro/') && rel.endsWith('/.gitignore')) return 'kiro';
  return null;
}

/// Active (non-blank, non-comment, non-negated) rules in an ignore file.
List<String> activeIgnoreRules(String text) => [
  for (final l in text.split('\n'))
    if (l.trim() case final r when r.isNotEmpty && !r.startsWith('#'))
      if (!r.startsWith('!')) r,
];

// ------------------------------------------------------ dart classification

/// Dart files the post-edit checks should look at: hand-written project
/// sources only. Generated and build output are skipped so the hooks never
/// fight tooling.
bool isCheckedDartFile(String rel) {
  if (!rel.endsWith('.dart')) return false;
  const roots = ['lib/', 'test/', 'tool/', 'integration_test/'];
  if (!roots.any(rel.startsWith)) return false;
  const generated = ['.g.dart', '.freezed.dart', '.mocks.dart', '.gr.dart'];
  if (generated.any(rel.endsWith)) return false;
  return !rel.contains('/generated/');
}

/// Code whose correctness the rest of the game depends on. These files also
/// get a targeted `dart analyze`.
bool isImportantCode(String rel) =>
    rel.startsWith('lib/domain/') ||
    rel.startsWith('lib/content/') ||
    rel.startsWith('lib/app/');

/// Focused tests to suggest after a change, or null when none apply.
/// Never the full suite: these run in seconds.
String? suggestedTests(String rel) {
  if (rel.startsWith('lib/domain/') || rel.startsWith('test/domain/')) {
    return 'flutter test test/domain';
  }
  if (rel.startsWith('lib/content/') ||
      rel.startsWith('assets/content/') ||
      rel.startsWith('test/content/')) {
    return 'flutter test test/content';
  }
  if (rel == 'lib/app/game_controller.dart' ||
      rel.startsWith('lib/features/room/') ||
      rel.startsWith('lib/features/puzzle/')) {
    return 'flutter test test/ui/exploration_test.dart';
  }
  return null;
}

// ---------------------------------------------------------------- .gitignore

/// Patterns that must be present so build output stays out of Git.
const requiredIgnores = <String, List<String>>{
  'build output': ['/build/', 'build/', '/build'],
  'Dart tool cache': ['.dart_tool/', '.dart_tool', '/.dart_tool/'],
  'Flutter plugin metadata': ['.flutter-plugins-dependencies'],
  'coverage output': ['/coverage/', 'coverage/'],
};

/// Problems with a root `.gitignore`: a rule that would hide `.kiro`, or a
/// missing rule for build artifacts.
List<Finding> checkGitignore(String text, {String path = '.gitignore'}) {
  final out = <Finding>[];
  final lines = text.split('\n');
  var kiroIgnoredAt = -1;
  var kiroReincluded = false;
  for (var i = 0; i < lines.length; i++) {
    final rule = lines[i].trim();
    if (rule.isEmpty || rule.startsWith('#')) continue;
    if (_reincludesKiro(rule)) {
      kiroReincluded = true;
    } else if (_ignoresKiro(rule)) {
      kiroIgnoredAt = i;
      kiroReincluded = false;
    }
  }
  if (kiroIgnoredAt >= 0 && !kiroReincluded) {
    out.add(
      Finding(
        path,
        'rule "${lines[kiroIgnoredAt].trim()}" would exclude .kiro/ (specs, steering, hooks) from Git. Remove it.',
        line: kiroIgnoredAt + 1,
      ),
    );
  }
  final rules = lines.map((l) => l.trim()).toSet();
  for (final e in requiredIgnores.entries) {
    if (!e.value.any(rules.contains)) {
      out.add(
        Finding(
          path,
          'missing an ignore rule for ${e.key} (for example "${e.value.first}").',
        ),
      );
    }
  }
  return out;
}

bool _ignoresKiro(String rule) {
  if (rule.startsWith('!')) return false;
  final r = rule
      .replaceAll(RegExp(r'^(\*\*/)'), '')
      .replaceAll(RegExp(r'^/'), '');
  // `.kiro`, `.kiro/`, `.kiro/*`, `.kiro/**`, `.kiro/steering`, and blanket
  // dotfile rules such as `.*` or `.*/`.
  return RegExp(r'^\.kiro(/.*)?$').hasMatch(r) ||
      RegExp(r'^\.\*/?$').hasMatch(r) ||
      RegExp(r'^\.k\*').hasMatch(r);
}

bool _reincludesKiro(String rule) =>
    RegExp(r'^!(\*\*/)?/?\.kiro/?(\*\*)?$').hasMatch(rule);

/// The `.gitignore` text that an agent write would produce.
String? proposedText(String tool, Map<String, Object?> input, String current) {
  switch (tool) {
    case 'fs_write':
      return input['text'] as String?;
    case 'fs_append':
      final add = input['text'] as String? ?? '';
      return current.endsWith('\n') || current.isEmpty
          ? '$current$add'
          : '$current\n$add';
    case 'str_replace':
      final oldStr = input['oldStr'] as String?;
      final newStr = input['newStr'] as String? ?? '';
      if (oldStr == null) return null;
      return input['replace_all'] == true
          ? current.replaceAll(oldStr, newStr)
          : current.replaceFirst(oldStr, newStr);
    default:
      return null;
  }
}

// ----------------------------------------------------------- shell commands

enum GitAction { none, commit, push }

/// Recognizes `git commit` and `git push` anywhere in a shell command line,
/// including chained commands and `git -C dir commit`.
GitAction gitActionOf(String command) {
  final segments = command.split(RegExp(r'&&|\|\||;|\|'));
  var action = GitAction.none;
  for (final s in segments) {
    final m = RegExp(r'(^|\s)git(\s+-[cC]\s+\S+)*\s+(commit|push)\b')
        .firstMatch(s.trim());
    if (m == null) continue;
    if (m.group(3) == 'push') return GitAction.push;
    action = GitAction.commit;
  }
  return action;
}

/// Whether the command stages files itself before committing.
bool stagesFiles(String command) =>
    RegExp(r'(^|\s)git\s+add\b').hasMatch(command) ||
    RegExp(
      r'git(\s+-[cC]\s+\S+)*\s+commit\b[^&;|]*\s-(a|[a-zA-Z]*a[a-zA-Z]*)\b',
    ).hasMatch(command) ||
    command.contains('--all');

// ------------------------------------------------------------ artifacts

/// Paths that must never be committed: build output, caches, local machine
/// files, keystores and environment files.
String? forbiddenPathReason(String rel) {
  const dirs = {
    'build/': 'build output',
    '.dart_tool/': 'Dart tool cache',
    '.gradle/': 'Gradle cache',
    'android/.gradle/': 'Gradle cache',
    'ios/Pods/': 'CocoaPods output',
    'macos/Pods/': 'CocoaPods output',
    'coverage/': 'coverage output',
    '.idea/': 'IDE settings',
  };
  for (final e in dirs.entries) {
    if (rel.startsWith(e.key) || rel.contains('/${e.key}')) return e.value;
  }
  final name = rel.split('/').last;
  if (name == '.env' || name.startsWith('.env.')) return 'environment file';
  if (name == 'local.properties') return 'machine-local Android SDK path';
  if (name == 'key.properties') return 'Android signing configuration';
  if (RegExp(r'\.(jks|keystore|p12|pem|key|mobileprovision)$').hasMatch(name)) {
    return 'key or signing material';
  }
  if (RegExp(r'\.(apk|aab|ipa|app\.dSYM)$').hasMatch(name)) {
    return 'built app package';
  }
  if (name == '.flutter-plugins-dependencies') {
    return 'generated plugin metadata';
  }
  return null;
}

// ---------------------------------------------------------------- secrets

class _SecretRule {
  const _SecretRule(this.name, this.pattern);
  final String name;
  final RegExp pattern;
}

final _secretRules = <_SecretRule>[
  _SecretRule(
    'private key',
    RegExp(r'-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY'),
  ),
  _SecretRule('AWS access key id', RegExp(r'\b(AKIA|ASIA)[0-9A-Z]{16}\b')),
  _SecretRule(
    'GitHub token',
    RegExp(
      r'\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b|\bgithub_pat_[A-Za-z0-9_]{40,}',
    ),
  ),
  _SecretRule('Google API key', RegExp(r'\bAIza[0-9A-Za-z_\-]{35}\b')),
  _SecretRule('Slack token', RegExp(r'\bxox[abprs]-[0-9A-Za-z-]{10,}')),
  _SecretRule('Stripe live key', RegExp(r'\b(sk|rk)_live_[0-9A-Za-z]{20,}')),
  _SecretRule(
    'OpenAI-style API key',
    RegExp(r'\bsk-(proj-)?[A-Za-z0-9_\-]{32,}'),
  ),
  _SecretRule('Anthropic API key', RegExp(r'\bsk-ant-[A-Za-z0-9_\-]{30,}')),
  _SecretRule(
    'hard-coded credential',
    RegExp(
      r'''(api[_-]?key|secret|token|password|passwd|auth[_-]?key|client[_-]?secret)["']?\s*[:=]\s*["'][^"'\s]{16,}["']''',
      caseSensitive: false,
    ),
  ),
];

/// Values that look like secrets but are clearly placeholders.
final _placeholder = RegExp(
  r'(example|placeholder|your[_-]?|xxxx|<[^>]+>|\$\{|changeme|dummy|test[_-]?key|redacted)',
  caseSensitive: false,
);

/// Obvious accidental secrets in [text]. Matches are reported by line with
/// the value masked, never printed in full.
List<Finding> scanForSecrets(String path, String text) {
  final out = <Finding>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('kiro-allow-secret')) continue;
    for (final rule in _secretRules) {
      final m = rule.pattern.firstMatch(line);
      if (m == null) continue;
      if (_placeholder.hasMatch(m.group(0)!)) continue;
      out.add(
        Finding(
          path,
          'possible ${rule.name}: ${_mask(m.group(0)!)}',
          line: i + 1,
        ),
      );
      break;
    }
  }
  return out;
}

String _mask(String s) => s.length <= 8
    ? '****'
    : '${s.substring(0, 4)}…${'*' * 4} (${s.length} chars)';
