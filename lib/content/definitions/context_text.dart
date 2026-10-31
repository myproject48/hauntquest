import 'condition.dart';
import 'json_helpers.dart';
import 'progress_view.dart';

/// One conditional alternative inside a [ContextText].
class TextVariant {
  const TextVariant({required this.when, required this.text});

  final Condition when;
  final String text;
}

/// Text that can change with player progress. The first variant whose
/// condition holds wins; otherwise [base] is used.
class ContextText {
  const ContextText(this.base, [this.variants = const []]);

  /// Accepts either a plain string or `{"base": ..., "variants": [...]}`.
  factory ContextText.fromJson(Object? json, [String ctx = 'text']) {
    if (json is String) {
      if (json.isEmpty) throw ContentFormatException('$ctx: text is empty');
      return ContextText(json);
    }
    final m = asMap(json, ctx);
    final variants = objectList(m, 'variants', ctx, required: false);
    return ContextText(reqString(m, 'base', ctx), [
      for (var i = 0; i < variants.length; i++)
        TextVariant(
          when: Condition.fromJson(
            variants[i]['when'],
            '$ctx.variants[$i].when',
          ),
          text: reqString(variants[i], 'text', '$ctx.variants[$i]'),
        ),
    ]);
  }

  final String base;
  final List<TextVariant> variants;

  /// Picks the text that matches the current progress.
  String resolve(ProgressView progress) {
    for (final v in variants) {
      if (v.when.evaluate(progress)) return v.text;
    }
    return base;
  }

  /// Every text this value can produce (used by validation).
  Iterable<String> get allTexts sync* {
    yield base;
    for (final v in variants) {
      yield v.text;
    }
  }
}
