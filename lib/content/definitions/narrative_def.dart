import 'condition.dart';
import 'context_text.dart';
import 'json_helpers.dart';

/// A discovery that remains readable after its source item is consumed.
class JournalEntryDef {
  const JournalEntryDef({
    required this.id,
    required this.title,
    required this.text,
    required this.unlockWhen,
  });
  factory JournalEntryDef.fromJson(JsonMap m, String ctx) => JournalEntryDef(
    id: reqString(m, 'id', ctx),
    title: reqString(m, 'title', ctx),
    text: ContextText.fromJson(m['text'], '$ctx.text'),
    unlockWhen: Condition.fromJson(m['unlockWhen'], '$ctx.unlockWhen'),
  );
  final String id;
  final String title;
  final ContextText text;
  final Condition unlockWhen;
}

/// An authored inference between two discovered journal entries.
class EvidenceLinkDef {
  const EvidenceLinkDef({
    required this.id,
    required this.from,
    required this.to,
    required this.label,
    this.requires,
  });
  factory EvidenceLinkDef.fromJson(JsonMap m, String ctx) => EvidenceLinkDef(
    id: reqString(m, 'id', ctx),
    from: reqString(m, 'from', ctx),
    to: reqString(m, 'to', ctx),
    label: reqString(m, 'label', ctx),
    requires: m['requires'] == null
        ? null
        : Condition.fromJson(m['requires'], '$ctx.requires'),
  );
  final String id;
  final String from;
  final String to;
  final String label;
  final Condition? requires;
}
