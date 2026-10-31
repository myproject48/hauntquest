import 'condition.dart';
import 'context_text.dart';
import 'effect.dart';
import 'json_helpers.dart';
import 'progress_view.dart';

enum DialogueReplay { transcript, never }

/// One selectable answer in a dialogue choice.
class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.label,
    required this.resultText,
    this.enabledWhen,
    this.disabledReason,
    this.effects = const [],
    this.nextChoiceId,
    this.reaction,
  });

  factory ChoiceOption.fromJson(JsonMap m, String ctx) => ChoiceOption(
    id: reqString(m, 'id', ctx),
    label: reqString(m, 'label', ctx),
    resultText: reqString(m, 'resultText', ctx),
    nextChoiceId: optString(m, 'nextChoiceId', ctx),
    reaction: m['reaction'] == null
        ? null
        : ContextText.fromJson(m['reaction'], '$ctx.reaction'),
    enabledWhen: m['enabledWhen'] == null
        ? null
        : Condition.fromJson(m['enabledWhen'], '$ctx.enabledWhen'),
    disabledReason: optString(m, 'disabledReason', ctx),
    effects: Effect.parseList(m, 'effects', ctx),
  );

  final String id;
  final String label;
  final String resultText;
  final Condition? enabledWhen;

  /// Required whenever [enabledWhen] is set.
  final String? disabledReason;
  final List<Effect> effects;
  final String? nextChoiceId;
  final ContextText? reaction;
  String responseFor(ProgressView state) =>
      reaction?.resolve(state) ?? resultText;
}

/// A dialogue or narrative decision. Resolved once; effects set story flags.
class ChoiceDef {
  const ChoiceDef({
    required this.id,
    required this.speakerId,
    required this.prompt,
    required this.options,
    this.requires,
    this.roomId,
    this.replay = DialogueReplay.transcript,
  });

  factory ChoiceDef.fromJson(JsonMap m, String ctx) => ChoiceDef(
    id: reqString(m, 'id', ctx),
    speakerId: reqString(m, 'speakerId', ctx),
    roomId: optString(m, 'roomId', ctx),
    replay: switch (m['replay']) {
      null || 'transcript' => DialogueReplay.transcript,
      'never' => DialogueReplay.never,
      _ => throw ContentFormatException('$ctx: invalid replay policy'),
    },
    prompt: ContextText.fromJson(m['prompt'], '$ctx.prompt'),
    requires: m['requires'] == null
        ? null
        : Condition.fromJson(m['requires'], '$ctx.requires'),
    options: [
      for (final (i, o) in objectList(m, 'options', ctx).indexed)
        ChoiceOption.fromJson(o, '$ctx.options[$i]'),
    ],
  );

  final String id;
  final String speakerId;
  final String? roomId;
  final DialogueReplay replay;
  final ContextText prompt;
  final Condition? requires;
  final List<ChoiceOption> options;
}
