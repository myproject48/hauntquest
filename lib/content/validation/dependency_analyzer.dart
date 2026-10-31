import '../definitions/condition.dart';
import '../definitions/effect.dart';
import '../game_content.dart';
import 'content_issue.dart';

/// A step in the progression graph: it needs tokens and produces tokens.
class _Node {
  _Node(this.id, this.needs, this.gives);

  final String id;

  /// AND of OR-groups: every group needs at least one satisfied token.
  final List<Set<String>> needs;
  final Set<String> gives;
}

/// Token-level dependency analysis over the whole content.
///
/// It finds mandatory steps whose requirements can never be met because
/// nothing provides them (missing dependency) or because providers depend on
/// each other (cyclic dependency). Numeric thresholds are ignored here; the
/// [ProgressionSimulator] covers those.
class DependencyAnalyzer {
  DependencyAnalyzer(this.content) {
    _build();
  }

  final GameContent content;
  final List<_Node> _nodes = [];
  final Set<String> _satisfied = {};
  final Set<String> _active = {};

  /// Order in which nodes first became available, for ordering output.
  final List<String> _activationOrder = [];

  /// Mandatory puzzle ids in a valid solve order (only those reachable).
  List<String> get puzzleOrder => [
    for (final id in _activationOrder)
      if (id.startsWith('puzzle:')) id.substring('puzzle:'.length),
  ];

  List<ContentIssue> analyze() {
    _solve();
    final issues = <ContentIssue>[];

    for (final puzzle in content.puzzles.where((p) => p.mandatory)) {
      final node = _nodes
          .where((n) => n.id == 'puzzle:${puzzle.id}')
          .firstOrNull;
      if (node == null || _active.contains(node.id)) continue;
      issues.addAll(_explain(node, 'Mandatory puzzle "${puzzle.id}"'));
    }
    for (final room in content.rooms) {
      if (!_satisfied.contains('room:${room.id}')) {
        issues.addAll(_explainToken('room:${room.id}', 'Room "${room.id}"'));
      }
    }
    for (final item in content.items) {
      if (!_satisfied.contains('item:${item.id}')) {
        issues.addAll(_explainToken('item:${item.id}', 'Item "${item.id}"'));
      }
    }
    for (final ending in content.story.endings) {
      if (!_satisfied.contains('ending:${ending.id}')) {
        issues.addAll(
          _explainToken('ending:${ending.id}', 'Ending "${ending.id}"'),
        );
      }
    }
    return issues;
  }

  // ---------------------------------------------------------------- build

  void _build() {
    final story = content.story;

    _nodes.add(
      _Node('start', [], {
        'room:${story.startRoomId}',
        for (final i in story.startItems) 'item:$i',
      }),
    );

    for (final exit in content.allExits) {
      _nodes.add(
        _Node(
          'exit:${exit.id}',
          [
            {'room:${exit.fromRoomId}'},
            if (!exit.initiallyOpen) {'exit:${exit.id}'},
          ],
          {'room:${exit.toRoomId}', if (exit.initiallyOpen) 'exit:${exit.id}'},
        ),
      );
    }

    for (final h in content.allHotspots) {
      final base = <Set<String>>[
        {'room:${h.roomId}'},
        ..._needsOf(h.requires),
      ];
      _nodes.add(
        _Node('hotspot:${h.id}', base, {
          'hotspot:${h.id}',
          ..._tokensOf(h.onExamine),
          if (h.choiceId != null) 'choicestart:${h.choiceId}',
        }),
      );
      for (final rule in h.useRules) {
        _nodes.add(
          _Node(
            'use:${h.id}:${rule.itemId}',
            [
              ...base,
              {'item:${rule.itemId}'},
              ..._needsOf(rule.when),
            ],
            {'hotspot:${h.id}', ..._tokensOf(rule.effects)},
          ),
        );
      }
    }

    for (final p in content.puzzles) {
      final hotspot = content.hotspotById(p.hotspotId);
      _nodes.add(
        _Node(
          'puzzle:${p.id}',
          [
            {'room:${p.roomId}'},
            ..._needsOf(hotspot?.requires),
            ..._needsOf(p.unlockWhen),
            for (final item in p.requiresItems) {'item:$item'},
            for (final clue in p.clues) {_clueToken(clue.source)},
          ],
          {'puzzle:${p.id}', ..._tokensOf(p.onSolved)},
        ),
      );
    }

    for (final c in content.choices) {
      _nodes.add(
        _Node(
          'choice:${c.id}',
          [
            {'choicestart:${c.id}'},
            ..._needsOf(c.requires),
          ],
          {
            'choice:${c.id}',
            for (final o in c.options) ..._tokensOf(o.effects),
          },
        ),
      );
    }

    for (final e in content.story.endings) {
      _nodes.add(
        _Node(
          'ending:${e.id}',
          [
            {'choice:${story.finalChoiceId}'},
          ],
          {'ending:${e.id}'},
        ),
      );
    }
  }

  static String _clueToken(String source) => source; // "item:x" / "hotspot:x"

  static List<Set<String>> _needsOf(Condition? c) {
    if (c == null) return const [];
    switch (c) {
      case Always():
        return const [];
      case HasItem(:final id):
        return [
          {'item:$id'},
        ];
      case PuzzleSolved(:final id):
        return [
          {'puzzle:$id'},
        ];
      case FlagAtLeast(:final id, :final value):
        return value > 0
            ? [
                {'flag:$id'},
              ]
            : const [];
      case FlagEquals(:final id, :final value):
        return value > 0
            ? [
                {'flag:$id'},
              ]
            : const [];
      case ExitOpen(:final id):
        return [
          {'exit:$id'},
        ];
      case Examined(:final id):
        return [
          {'hotspot:$id'},
        ];
      case ChoiceResolved(:final id):
        return [
          {'choice:$id'},
        ];
      case VisitedRoom(:final id):
        return [
          {'room:$id'},
        ];
      case All(:final items):
        return [for (final i in items) ..._needsOf(i)];
      case Any(:final items):
        final groups = items.map(_needsOf).toList();
        if (groups.any((g) => g.isEmpty)) return const [];
        return [
          {
            for (final g in groups)
              for (final s in g) ...s,
          },
        ];
      case Not():
        return const [];
    }
  }

  static Set<String> _tokensOf(Iterable<Effect> effects) {
    final out = <String>{};
    for (final e in effects) {
      switch (e) {
        case GiveItem(:final id):
          out.add('item:$id');
        case SetFlag(:final id, :final value):
          if (value > 0) out.add('flag:$id');
        case AddFlag(:final id):
          out.add('flag:$id');
        case OpenExit(:final id):
          out.add('exit:$id');
        case StartChoice(:final id):
          out.add('choicestart:$id');
        case ConsumeItem():
          break;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- solve

  void _solve() {
    var changed = true;
    while (changed) {
      changed = false;
      for (final node in _nodes) {
        if (_active.contains(node.id)) continue;
        final ready = node.needs.every((g) => g.any(_satisfied.contains));
        if (!ready) continue;
        _active.add(node.id);
        _activationOrder.add(node.id);
        _satisfied.addAll(node.gives);
        changed = true;
      }
    }
  }

  // -------------------------------------------------------------- explain

  List<_Node> _producers(String token) =>
      _nodes.where((n) => n.gives.contains(token)).toList();

  List<ContentIssue> _explainToken(String token, String label) {
    final producers = _producers(token);
    if (producers.isEmpty) {
      return [
        ContentIssue.error(
          'missing_dependency',
          '$label can never be reached: nothing provides "$token".',
        ),
      ];
    }
    final out = <ContentIssue>[];
    for (final p in producers.where((p) => !_active.contains(p.id))) {
      out.addAll(_explain(p, label));
    }
    return out;
  }

  List<ContentIssue> _explain(_Node node, String label) {
    final out = <ContentIssue>[];
    for (final group in node.needs.where((g) => !g.any(_satisfied.contains))) {
      final anyProducer = group.any((t) => _producers(t).isNotEmpty);
      if (!anyProducer) {
        out.add(
          ContentIssue.error(
            'missing_dependency',
            '$label (${node.id}) needs one of {${group.join(', ')}} but nothing provides it.',
          ),
        );
        continue;
      }
      final cycle = _findCycle(node);
      if (cycle != null) {
        out.add(
          ContentIssue.error(
            'cyclic_dependency',
            '$label (${node.id}) is blocked by a dependency cycle: ${cycle.join(' -> ')}.',
          ),
        );
      } else {
        out.add(
          ContentIssue.error(
            'unreachable_dependency',
            '$label (${node.id}) is blocked: {${group.join(', ')}} is never satisfied.',
          ),
        );
      }
    }
    return out;
  }

  /// Finds a cycle among inactive nodes reachable from [start].
  List<String>? _findCycle(_Node start) {
    final path = <String>[];
    final done = <String>{};

    List<String>? visit(_Node node) {
      final at = path.indexOf(node.id);
      if (at >= 0) return [...path.sublist(at), node.id];
      if (done.contains(node.id)) return null;
      path.add(node.id);
      for (final group in node.needs.where(
        (g) => !g.any(_satisfied.contains),
      )) {
        for (final token in group) {
          for (final p in _producers(
            token,
          ).where((p) => !_active.contains(p.id))) {
            final found = visit(p);
            if (found != null) return found;
          }
        }
      }
      path.removeLast();
      done.add(node.id);
      return null;
    }

    return visit(start);
  }
}
