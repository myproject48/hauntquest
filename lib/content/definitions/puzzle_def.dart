import 'condition.dart';
import 'effect.dart';
import 'json_helpers.dart';

/// Mechanic used by a puzzle.
enum PuzzleKind { sequence, cipher, dial, combine, useItem, clock, gears }

/// Declares that the text of [source] must contain [contains], so the
/// solution is discoverable. [source] is `item:<id>` or `hotspot:<id>`.
class ClueRef {
  const ClueRef({required this.source, required this.contains});

  factory ClueRef.fromJson(JsonMap m, String ctx) => ClueRef(
    source: reqString(m, 'source', ctx),
    contains: reqString(m, 'contains', ctx),
  );

  final String source;
  final String contains;

  bool get isItem => source.startsWith('item:');
  bool get isHotspot => source.startsWith('hotspot:');
  String get sourceId => source.substring(source.indexOf(':') + 1);
}

/// A puzzle definition. The solution lives in [config] (content data), never
/// in widget code.
class PuzzleDef {
  const PuzzleDef({
    required this.id,
    required this.roomId,
    required this.hotspotId,
    required this.title,
    required this.kind,
    required this.mandatory,
    required this.config,
    required this.intro,
    required this.successText,
    required this.incorrectText,
    required this.hints,
    this.partialText,
    this.unlockWhen,
    this.requiresItems = const [],
    this.consumesItems = const [],
    this.clues = const [],
    this.onSolved = const [],
  });

  factory PuzzleDef.fromJson(JsonMap m, String ctx) {
    final kindName = reqString(m, 'kind', ctx);
    final kind = PuzzleKind.values.where((k) => k.name == kindName).firstOrNull;
    if (kind == null) {
      throw ContentFormatException('$ctx: unknown puzzle kind "$kindName"');
    }
    return PuzzleDef(
      id: reqString(m, 'id', ctx),
      roomId: reqString(m, 'roomId', ctx),
      hotspotId: reqString(m, 'hotspotId', ctx),
      title: reqString(m, 'title', ctx),
      kind: kind,
      mandatory: optBool(m, 'mandatory', ctx, fallback: true),
      config: asMap(m['config'], '$ctx.config'),
      intro: reqString(m, 'intro', ctx),
      successText: reqString(m, 'successText', ctx),
      incorrectText: reqString(m, 'incorrectText', ctx),
      partialText: optString(m, 'partialText', ctx),
      unlockWhen: m['unlockWhen'] == null
          ? null
          : Condition.fromJson(m['unlockWhen'], '$ctx.unlockWhen'),
      requiresItems: stringList(m, 'requiresItems', ctx),
      consumesItems: stringList(m, 'consumesItems', ctx),
      clues: [
        for (final (i, c) in objectList(
          m,
          'clues',
          ctx,
          required: false,
        ).indexed)
          ClueRef.fromJson(c, '$ctx.clues[$i]'),
      ],
      onSolved: Effect.parseList(m, 'onSolved', ctx),
      hints: stringList(m, 'hints', ctx, required: true),
    );
  }

  final String id;
  final String roomId;
  final String hotspotId;
  final String title;
  final PuzzleKind kind;

  /// Mandatory puzzles must be solvable in every valid playthrough.
  final bool mandatory;

  /// Kind-specific data, including the solution.
  final JsonMap config;
  final String intro;
  final String successText;
  final String incorrectText;
  final String? partialText;
  final Condition? unlockWhen;
  final List<String> requiresItems;
  final List<String> consumesItems;
  final List<ClueRef> clues;
  final List<Effect> onSolved;

  /// Exactly three tiers: nudge, clue, solution outline.
  final List<String> hints;
}
