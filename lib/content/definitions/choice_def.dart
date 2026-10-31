import 'condition.dart';
import 'context_text.dart';
import 'effect.dart';
import 'json_helpers.dart';

/// One selectable answer in a dialogue choice.
class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.label,
    required this.resultText,
    this.enabledWhen,
    this.disabledReason,
    this.effects = const [],
  });

  factory ChoiceOption.fromJson(JsonMap m, String ctx) => ChoiceOption(
    id: reqString(m, 'id', ctx),
    label: reqString(m, 'label', ctx),
    resultText: reqString(m, 'resultText', ctx),
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
}

/// A dialogue or narrative decision. Resolved once; effects set story flags.
class ChoiceDef {
  const ChoiceDef({
    required this.id,
    required this.speakerId,
    required this.prompt,
    required this.options,
    this.requires,
  });

  factory ChoiceDef.fromJson(JsonMap m, String ctx) => ChoiceDef(
    id: reqString(m, 'id', ctx),
    speakerId: reqString(m, 'speakerId', ctx),
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
  final ContextText prompt;
  final Condition? requires;
  final List<ChoiceOption> options;
}
