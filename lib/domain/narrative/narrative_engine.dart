import '../../content/definitions/choice_def.dart';
import '../../content/definitions/narrative_def.dart';
import '../../content/game_content.dart';
import '../models/game_state.dart';
import 'dialogue_record.dart';

/// Narrative queries are pure projections of authored content and saved state.
/// Widgets render these results; they never decide which branch was earned.
class NarrativeEngine {
  const NarrativeEngine(this.content);
  final GameContent content;

  bool choiceAvailable(GameState s, ChoiceDef c) {
    if (s.endingId != null || s.choiceResolved(c.id)) return false;
    if (c.roomId != null && c.roomId != s.currentRoomId) return false;
    if (!(c.requires?.evaluate(s) ?? true)) return false;
    if (s.pendingChoiceIds.contains(c.id)) return true;
    return content
        .roomById(s.currentRoomId)!
        .hotspots
        .any((h) => h.choiceId == c.id && (h.requires?.evaluate(s) ?? true));
  }

  bool optionEnabled(GameState s, ChoiceOption o) =>
      o.enabledWhen?.evaluate(s) ?? true;

  DialogueRecord? transcript(GameState s, ChoiceDef c) {
    if (c.replay == DialogueReplay.never || !s.choiceResolved(c.id)) {
      return null;
    }
    if (s.dialogueRecords[c.id] case final record?) return record;
    // Older saves have the selected option but no captured text.
    final option = c.options
        .where((o) => o.id == s.resolvedChoices[c.id])
        .firstOrNull;
    return option == null
        ? null
        : DialogueRecord(
            prompt: c.prompt.resolve(s),
            response: option.resultText,
          );
  }

  List<JournalEntryDef> journal(GameState s) => [
    for (final entry in content.story.journalEntries)
      if (s.journalEntryIds.contains(entry.id) || entry.unlockWhen.evaluate(s))
        entry,
  ];

  List<EvidenceLinkDef> connections(GameState s) {
    final discovered = journal(s).map((e) => e.id).toSet();
    return [
      for (final link in content.story.evidenceLinks)
        if (discovered.contains(link.from) &&
            discovered.contains(link.to) &&
            (link.requires?.evaluate(s) ?? true))
          link,
    ];
  }
}
