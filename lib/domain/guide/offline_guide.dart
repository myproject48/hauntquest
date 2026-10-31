import '../../content/definitions/puzzle_def.dart';
import '../../content/game_content.dart';
import '../models/game_state.dart';
import '../narrative/narrative_engine.dart';
import 'guide_models.dart';

/// Pure, deterministic guidance over DISCOVERED content. This service never
/// imports GameController, applies effects, or reads unchosen dialogue branches.
class OfflineGuide {
  const OfflineGuide(this.content);
  final GameContent content;

  List<GuideTopic> topics(GameState state) => [
    const GuideTopic(
      id: 'room',
      title: 'What can I do here?',
      intent: GuideIntent.progress,
    ),
    for (final p in content.puzzles)
      if (_encountered(p, state))
        GuideTopic(
          id: 'puzzle:${p.id}',
          title: p.title,
          intent: GuideIntent.progress,
        ),
    for (final fact in _facts(state))
      GuideTopic(id: fact.id, title: fact.title, intent: GuideIntent.evidence),
  ];

  bool _encountered(PuzzleDef p, GameState s) =>
      p.roomId == s.currentRoomId &&
      s.examined(p.hotspotId) &&
      (content.hotspotById(p.hotspotId)?.requires?.evaluate(s) ?? true);

  /// A phonograph's clue is not known merely because its empty cradle was
  /// examined. Use-rule text becomes evidence only after that rule was played.
  bool clueKnown(ClueRef clue, GameState s) {
    final needle = clue.contains.toLowerCase();
    if (clue.isItem) {
      final item = content.itemById(clue.sourceId);
      return s.wasAcquired(clue.sourceId) &&
          item != null &&
          '${item.description.resolve(s)} ${item.detail.resolve(s)}'
              .toLowerCase()
              .contains(needle);
    }
    if (clue.isHotspot) {
      final h = content.hotspotById(clue.sourceId);
      if (h == null || !s.examined(h.id)) return false;
      if ('${h.description.resolve(s)} ${h.repeatText.resolve(s)}'
          .toLowerCase()
          .contains(needle)) {
        return true;
      }
      return h.useRules.any(
        (rule) =>
            s.usedRuleKeys.contains('${h.id}|${rule.itemId}') &&
            rule.successText.toLowerCase().contains(needle),
      );
    }
    return false;
  }

  GuidePlan plan(
    GameState state, {
    String topicId = 'room',
    HintLevel level = HintLevel.subtle,
  }) {
    final topic =
        topics(state).where((t) => t.id == topicId).firstOrNull ??
        topics(state).first;
    final facts = _facts(state);
    String text;
    final supporting = <String>[];
    if (topic.intent == GuideIntent.evidence) {
      final fact = facts.firstWhere((f) => f.id == topic.id);
      final connections = NarrativeEngine(content)
          .connections(state)
          .where(
            (link) =>
                topic.id == 'journal:${link.from}' ||
                topic.id == 'journal:${link.to}',
          )
          .toList();
      text = switch (level) {
        HintLevel.subtle =>
          'You have already discovered ${fact.title}. Reread it before drawing a new conclusion.',
        HintLevel.guided =>
          connections.isEmpty
              ? '${fact.text}\n\nNo connection to another discovered clue is established yet.'
              : '${fact.text}\n\n${connections.first.label}',
        HintLevel.direct =>
          '${fact.text}\n\n${connections.isEmpty ? 'The evidence supports no further recorded connection yet. Keep investigating without assuming an unseen answer.' : connections.map((c) => c.label).take(3).join('\n')}',
      };
      if (level != HintLevel.subtle) {
        supporting.addAll(connections.map((c) => c.label).take(2));
      }
    } else {
      final explicit = topic.id.startsWith('puzzle:')
          ? content.puzzleById(topic.id.substring(7))
          : null;
      final puzzle =
          explicit ??
          content.puzzles
              .where((p) => _encountered(p, state) && !state.puzzleSolved(p.id))
              .firstOrNull;
      if (state.endingId != null) {
        text = 'Your decision is complete. You can reread the ending you earned and the discoveries in your journal. The Guide cannot change that decision.';
      } else if (puzzle != null) {
        text = _puzzleHint(puzzle, state, level);
        // Supporting evidence must be known, scoped to THIS puzzle and safe at
        // THIS tier. Subtle requests never receive direct-answer passages.
        if (level == HintLevel.direct && _cluesReady(puzzle, state)) {
          for (final clue in puzzle.clues) {
            if (clueKnown(clue, state)) {
              supporting.add('Discovered clue: ${clue.contains}');
            }
          }
        }
      } else {
        final room = content.roomById(state.currentRoomId)!;
        final next = room.hotspots
            .where(
              (h) =>
                  !state.examined(h.id) &&
                  (h.requires?.evaluate(state) ?? true),
            )
            .firstOrNull;
        if (next != null) {
          text = switch (level) {
            HintLevel.subtle =>
              'Look for something you have not examined in ${room.name}. The manor keeps its clues in ordinary objects.',
            HintLevel.guided =>
              'Take a closer look at the ${next.label.toLowerCase()}. Read what it actually reveals before assuming a solution.',
            HintLevel.direct =>
              'Inspect the ${next.label.toLowerCase()}, then use its available controls. Nothing unlocks until you act; the Guide cannot act for you.',
          };
        } else {
          final pending = state.pendingChoiceIds.where((id) {
            final c = content.choiceById(id);
            return c != null &&
                NarrativeEngine(content).choiceAvailable(state, c);
          }).isNotEmpty;
          final exit = room.exits
              .where((e) => e.initiallyOpen || state.exitOpen(e.id))
              .firstOrNull;
          text = pending
              ? 'A discovered voice is waiting. Continue its conversation from the Story tab in your journal; the choice remains yours.'
              : exit != null
              ? 'You have examined the accessible objects here. An open way is available: ${exit.label}. You can also revisit your discovered clues.'
              : 'Reread the evidence you have collected and revisit objects you have examined. There is no newly discovered answer for the Guide to reveal yet.';
        }
      }
    }
    final passages = [
      GuidePassage('p0', text),
      for (final (i, evidence) in supporting.toSet().take(2).indexed)
        GuidePassage('p${i + 1}', evidence),
    ];
    return GuidePlan(
      topic: topic,
      level: level,
      offlineText: text,
      passages: passages,
    );
  }

  bool _cluesReady(PuzzleDef p, GameState s) =>
      p.clues.every((c) => clueKnown(c, s)) &&
      p.requiresItems.every(s.hasItem) &&
      (p.unlockWhen?.evaluate(s) ?? true);

  String _puzzleHint(PuzzleDef p, GameState s, HintLevel level) {
    if (s.puzzleSolved(p.id)) {
      return 'You already solved ${p.title}. ${p.successText} Reopening it will not grant another reward.';
    }
    if (!_cluesReady(p, s)) {
      final known = p.clues.where((c) => clueKnown(c, s)).length;
      return switch (level) {
        HintLevel.subtle =>
          'You have not discovered everything needed for ${p.title}. Work from evidence you have actually found.',
        HintLevel.guided =>
          p.clues.isEmpty || known == p.clues.length
              ? 'This mechanism still needs an item or an earlier action. Inspect accessible objects and check the evidence and items you already carry.'
              : 'You know $known of ${p.clues.length} recorded clues for this mechanism. Inspect the remaining accessible objects and reread your collected evidence.',
        HintLevel.direct => 'More discovery or an earlier action is needed before this answer can be explained. Examine accessible objects here, then retrace rooms you have already visited. The Guide will not reveal unseen clues or create missing items.',
      };
    }
    final draft = s.puzzleProgress[p.id];
    final attempts = s.puzzleAttempts[p.id] ?? 0;
    final preface = level == HintLevel.subtle && attempts > 0
        ? 'Your $attempts ${attempts == 1 ? 'attempt has' : 'attempts have'} not solved the mechanism. '
        : draft != null && level == HintLevel.guided
        ? 'Your unfinished input is still saved. '
        : '';
    return '$preface${p.hints[level.index]}';
  }

  List<_KnownFact> _facts(GameState s) => [
    for (final entry in NarrativeEngine(content).journal(s))
      _KnownFact('journal:${entry.id}', entry.title, entry.text.resolve(s)),
    for (final item in content.items)
      if (s.wasAcquired(item.id))
        _KnownFact('item:${item.id}', item.name, item.detail.resolve(s)),
    // Only captured exchanges, never unchosen options or unresolved nodes.
    for (final entry in s.dialogueRecords.entries)
      if (s.choiceResolved(entry.key) && content.choiceById(entry.key) != null)
        _KnownFact(
          'dialogue:${entry.key}',
          'Recorded voice: ${content.characterById(content.choiceById(entry.key)!.speakerId)!.name}',
          entry.value.response,
        ),
  ];
}

class _KnownFact {
  const _KnownFact(this.id, this.title, this.text);
  final String id;
  final String title;
  final String text;
}
