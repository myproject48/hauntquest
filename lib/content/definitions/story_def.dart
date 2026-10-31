import 'condition.dart';
import 'json_helpers.dart';

/// A named story flag with an integer range. Booleans use range 0 to 1.
class FlagDef {
  const FlagDef({
    required this.id,
    required this.min,
    required this.max,
    required this.initial,
  });

  factory FlagDef.fromJson(JsonMap m, String ctx) => FlagDef(
    id: reqString(m, 'id', ctx),
    min: reqInt(m, 'min', ctx),
    max: reqInt(m, 'max', ctx),
    initial: optInt(m, 'initial', ctx),
  );

  final String id;
  final int min;
  final int max;
  final int initial;
}

/// A speaking character or voice, with writing guidance.
class CharacterDef {
  const CharacterDef({
    required this.id,
    required this.name,
    required this.role,
    required this.voice,
    required this.accent,
  });

  factory CharacterDef.fromJson(JsonMap m, String ctx) => CharacterDef(
    id: reqString(m, 'id', ctx),
    name: reqString(m, 'name', ctx),
    role: reqString(m, 'role', ctx),
    voice: reqString(m, 'voice', ctx),
    accent: reqString(m, 'accent', ctx),
  );

  final String id;
  final String name;
  final String role;

  /// Writing guidance for this voice.
  final String voice;

  /// Name of the [AppColors] token used for this speaker.
  final String accent;
}

class EndingDef {
  const EndingDef({
    required this.id,
    required this.title,
    required this.epilogue,
    required this.sceneId,
    required this.musicCue,
  });

  factory EndingDef.fromJson(JsonMap m, String ctx) => EndingDef(
    id: reqString(m, 'id', ctx),
    title: reqString(m, 'title', ctx),
    epilogue: stringList(m, 'epilogue', ctx, required: true),
    sceneId: reqString(m, 'sceneId', ctx),
    musicCue: reqString(m, 'musicCue', ctx),
  );

  final String id;
  final String title;
  final List<String> epilogue;
  final String sceneId;
  final String musicCue;
}

/// Ordered ending rule. The first rule whose [when] holds picks the ending.
class EndingRule {
  const EndingRule({required this.when, required this.endingId});

  factory EndingRule.fromJson(JsonMap m, String ctx) => EndingRule(
    when: Condition.fromJson(m['when'], '$ctx.when'),
    endingId: reqString(m, 'endingId', ctx),
  );

  final Condition when;
  final String endingId;
}

/// Story-level data from `story.json`.
class StoryDef {
  const StoryDef({
    required this.title,
    required this.tagline,
    required this.premise,
    required this.startRoomId,
    required this.startItems,
    required this.introLines,
    required this.finalChoiceId,
    required this.characters,
    required this.flags,
    required this.endings,
    required this.endingRules,
  });

  factory StoryDef.fromJson(JsonMap m) {
    const ctx = 'story';
    return StoryDef(
      title: reqString(m, 'title', ctx),
      tagline: reqString(m, 'tagline', ctx),
      premise: reqString(m, 'premise', ctx),
      startRoomId: reqString(m, 'startRoomId', ctx),
      startItems: stringList(m, 'startItems', ctx),
      introLines: stringList(m, 'introLines', ctx, required: true),
      finalChoiceId: reqString(m, 'finalChoiceId', ctx),
      characters: [
        for (final (i, c) in objectList(m, 'characters', ctx).indexed)
          CharacterDef.fromJson(c, 'story.characters[$i]'),
      ],
      flags: [
        for (final (i, f) in objectList(m, 'flags', ctx).indexed)
          FlagDef.fromJson(f, 'story.flags[$i]'),
      ],
      endings: [
        for (final (i, e) in objectList(m, 'endings', ctx).indexed)
          EndingDef.fromJson(e, 'story.endings[$i]'),
      ],
      endingRules: [
        for (final (i, r) in objectList(m, 'endingRules', ctx).indexed)
          EndingRule.fromJson(r, 'story.endingRules[$i]'),
      ],
    );
  }

  final String title;
  final String tagline;
  final String premise;
  final String startRoomId;
  final List<String> startItems;
  final List<String> introLines;

  /// The choice whose resolution ends the game.
  final String finalChoiceId;
  final List<CharacterDef> characters;
  final List<FlagDef> flags;
  final List<EndingDef> endings;
  final List<EndingRule> endingRules;
}
