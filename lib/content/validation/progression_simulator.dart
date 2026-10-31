import '../definitions/effect.dart';
import '../definitions/progress_view.dart';
import '../game_content.dart';
import 'content_issue.dart';

/// Simulated player progress. Implements [ProgressView] so authored
/// conditions are evaluated exactly as the real game will evaluate them.
class SimState implements ProgressView {
  SimState(this.content);

  SimState._copy(SimState o)
    : content = o.content,
      inventory = {...o.inventory},
      acquired = {...o.acquired},
      solved = {...o.solved},
      openExits = {...o.openExits},
      examinedHotspots = {...o.examinedHotspots},
      resolved = {...o.resolved},
      started = {...o.started},
      visited = {...o.visited},
      known = {...o.known},
      usedRules = {...o.usedRules},
      flags = {...o.flags};

  final GameContent content;
  Set<String> inventory = {};
  Set<String> acquired = {};
  Set<String> solved = {};
  Set<String> openExits = {};
  Set<String> examinedHotspots = {};
  Set<String> resolved = {};
  Set<String> started = {};
  Set<String> visited = {};

  /// Clue sources the player has seen: `item:<id>` or `hotspot:<id>`.
  Set<String> known = {};
  Set<String> usedRules = {};
  Map<String, int> flags = {};

  SimState clone() => SimState._copy(this);

  @override
  bool hasItem(String id) => inventory.contains(id);
  @override
  bool puzzleSolved(String id) => solved.contains(id);
  @override
  int flag(String id) => flags[id] ?? content.flagById(id)?.initial ?? 0;
  @override
  bool exitOpen(String id) =>
      openExits.contains(id) || (content.exitById(id)?.initiallyOpen ?? false);
  @override
  bool examined(String id) => examinedHotspots.contains(id);
  @override
  bool choiceResolved(String id) => resolved.contains(id);
  @override
  bool visitedRoom(String id) => visited.contains(id);

  void apply(Effect e) {
    switch (e) {
      case GiveItem(:final id):
        if (acquired.add(id)) {
          inventory.add(id);
          known.add('item:$id');
        }
      case ConsumeItem(:final id):
        inventory.remove(id);
      case SetFlag(:final id, :final value):
        flags[id] = _clamp(id, value);
      case AddFlag(:final id, :final amount):
        flags[id] = _clamp(id, flag(id) + amount);
      case OpenExit(:final id):
        openExits.add(id);
      case StartChoice(:final id):
        if (!resolved.contains(id)) started.add(id);
    }
  }

  int _clamp(String id, int value) {
    final def = content.flagById(id);
    if (def == null) return value;
    return value.clamp(def.min, def.max);
  }
}

/// One finished simulated playthrough.
class SimLeaf {
  const SimLeaf(this.state, this.options, this.endingId);

  final SimState state;

  /// Choice option ids picked in this playthrough.
  final List<String> options;

  /// Ending reached, or null if the playthrough got stuck.
  final String? endingId;
}

/// Plays the game abstractly: repeatedly performs every available action
/// until nothing new is possible, branching on each dialogue choice.
///
/// Soundness relies on two content rules enforced elsewhere in validation:
/// effects are idempotent, and every consumable item has one consumer.
class ProgressionSimulator {
  ProgressionSimulator(this.content, {this.maxLeaves = 20000});

  final GameContent content;
  final int maxLeaves;

  final List<SimLeaf> leaves = [];
  bool truncated = false;

  SimState initialState() {
    final s = SimState(content);
    s.visited.add(content.story.startRoomId);
    for (final id in content.story.startItems) {
      s.apply(GiveItem(id));
    }
    return s;
  }

  /// Runs all branches and returns issues found.
  List<ContentIssue> run() {
    leaves.clear();
    truncated = false;
    _explore(initialState(), const []);
    final issues = <ContentIssue>[];

    if (truncated) {
      issues.add(
        ContentIssue.error(
          'simulation_truncated',
          'More than $maxLeaves choice combinations; validation is incomplete.',
        ),
      );
    }

    final reachedEndings = {for (final l in leaves) ?l.endingId};
    for (final ending in content.story.endings) {
      if (!reachedEndings.contains(ending.id)) {
        issues.add(
          ContentIssue.error(
            'ending_unreachable',
            'Ending "${ending.id}" cannot be reached by any sequence of valid choices.',
          ),
        );
      }
    }

    for (final leaf in leaves) {
      final route = leaf.options.isEmpty
          ? '(no choices)'
          : leaf.options.join(', ');
      if (leaf.endingId == null) {
        issues.add(
          ContentIssue.error(
            'dead_end',
            'A playthrough ends without reaching an ending. Choices: $route.',
          ),
        );
      }
      for (final p in content.puzzles.where((p) => p.mandatory)) {
        if (!leaf.state.solved.contains(p.id)) {
          issues.add(
            ContentIssue.error(
              'unsolvable_mandatory_puzzle',
              'Mandatory puzzle "${p.id}" is not solvable. Choices: $route.',
            ),
          );
        }
      }
      for (final room in content.rooms) {
        if (!leaf.state.visited.contains(room.id)) {
          issues.add(
            ContentIssue.error(
              'unreachable_room',
              'Room "${room.id}" is not reachable. Choices: $route.',
            ),
          );
        }
      }
    }

    final everAcquired = {for (final l in leaves) ...l.state.acquired};
    for (final item in content.items) {
      if (!everAcquired.contains(item.id)) {
        issues.add(
          ContentIssue.error(
            'item_unobtainable',
            'Item "${item.id}" can never be obtained.',
          ),
        );
      }
    }
    final everExamined = {for (final l in leaves) ...l.state.examinedHotspots};
    for (final h in content.allHotspots) {
      if (!everExamined.contains(h.id)) {
        issues.add(
          ContentIssue.error(
            'hotspot_unreachable',
            'Hotspot "${h.id}" can never be examined.',
          ),
        );
      }
    }
    return _dedupe(issues);
  }

  /// Example route and count for each reachable ending.
  List<EndingRoute> endingRoutes() {
    final byEnding = <String, List<SimLeaf>>{};
    for (final l in leaves) {
      final id = l.endingId;
      if (id != null) byEnding.putIfAbsent(id, () => []).add(l);
    }
    return [
      for (final ending in content.story.endings)
        if (byEnding[ending.id] case final list?)
          EndingRoute(ending.id, list.first.options, list.length),
    ];
  }

  // ------------------------------------------------------------- internals

  void _explore(SimState s, List<String> path) {
    if (leaves.length >= maxLeaves) {
      truncated = true;
      return;
    }
    _closure(s);

    final pending = [
      for (final id in s.started)
        if (!s.resolved.contains(id) &&
            (content.choiceById(id)?.requires?.evaluate(s) ?? true))
          id,
    ];

    final choice = pending.isEmpty ? null : content.choiceById(pending.first);
    if (choice == null) {
      leaves.add(SimLeaf(s, path, _endingFor(s)));
      return;
    }

    var anyEnabled = false;
    for (final option in choice.options) {
      if (!(option.enabledWhen?.evaluate(s) ?? true)) continue;
      anyEnabled = true;
      final next = s.clone();
      for (final e in option.effects) {
        next.apply(e);
      }
      next.resolved.add(choice.id);
      next.started.remove(choice.id);
      _explore(next, [...path, option.id]);
    }
    if (!anyEnabled) {
      // A choice with no enabled option can never be resolved.
      leaves.add(SimLeaf(s, [...path, '${choice.id}:no-enabled-option'], null));
    }
  }

  String? _endingFor(SimState s) {
    if (!s.resolved.contains(content.story.finalChoiceId)) return null;
    return content.resolveEnding(s);
  }

  /// Performs every non-choice action until nothing changes.
  void _closure(SimState s) {
    var changed = true;
    while (changed) {
      changed = false;

      for (final room in content.rooms.where((r) => s.visited.contains(r.id))) {
        for (final exit in room.exits) {
          if (s.exitOpen(exit.id) && s.visited.add(exit.toRoomId)) {
            changed = true;
          }
        }
      }

      for (final room in content.rooms.where((r) => s.visited.contains(r.id))) {
        for (final h in room.hotspots) {
          if (!(h.requires?.evaluate(s) ?? true)) continue;

          if (s.examinedHotspots.add(h.id)) {
            changed = true;
            s.known.add('hotspot:${h.id}');
            for (final e in h.onExamine) {
              s.apply(e);
            }
          }

          final choiceId = h.choiceId;
          if (choiceId != null) {
            final choice = content.choiceById(choiceId);
            if (choice != null &&
                !s.resolved.contains(choiceId) &&
                (choice.requires?.evaluate(s) ?? true) &&
                s.started.add(choiceId)) {
              changed = true;
            }
          }

          for (final rule in h.useRules) {
            final key = '${h.id}|${rule.itemId}';
            if (s.usedRules.contains(key)) continue;
            if (!s.hasItem(rule.itemId)) continue;
            if (!(rule.when?.evaluate(s) ?? true)) continue;
            s.usedRules.add(key);
            s.known.add('hotspot:${h.id}');
            for (final e in rule.effects) {
              s.apply(e);
            }
            if (rule.consumeItem) s.inventory.remove(rule.itemId);
            changed = true;
          }
        }
      }

      for (final p in content.puzzles) {
        if (s.solved.contains(p.id)) continue;
        if (!s.visited.contains(p.roomId)) continue;
        final hotspot = content.hotspotById(p.hotspotId);
        if (!(hotspot?.requires?.evaluate(s) ?? true)) continue;
        if (!(p.unlockWhen?.evaluate(s) ?? true)) continue;
        if (!p.requiresItems.every(s.hasItem)) continue;
        if (!p.clues.every((c) => s.known.contains(c.source))) continue;
        s.solved.add(p.id);
        for (final item in p.consumesItems) {
          s.inventory.remove(item);
        }
        for (final e in p.onSolved) {
          s.apply(e);
        }
        changed = true;
      }
    }
  }

  /// Collapses repeated identical issues from many branches.
  static List<ContentIssue> _dedupe(List<ContentIssue> issues) {
    final counts = <String, int>{};
    final first = <String, ContentIssue>{};
    for (final i in issues) {
      final key = '${i.code}|${i.message.split(' Choices:').first}';
      counts.update(key, (c) => c + 1, ifAbsent: () => 1);
      first.putIfAbsent(key, () => i);
    }
    return [
      for (final e in first.entries)
        counts[e.key]! > 1
            ? ContentIssue(
                e.value.severity,
                e.value.code,
                '${e.value.message} (in ${counts[e.key]} playthroughs)',
              )
            : e.value,
    ];
  }
}
