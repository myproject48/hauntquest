import 'json_helpers.dart';
import 'progress_view.dart';

/// A pure predicate over player progress, declared in content JSON.
sealed class Condition {
  const Condition();

  /// Parses a condition such as `{"type": "hasItem", "id": "key"}`.
  factory Condition.fromJson(Object? json, [String ctx = 'condition']) {
    final m = asMap(json, ctx);
    final type = reqString(m, 'type', ctx);
    switch (type) {
      case 'always':
        return const Always();
      case 'hasItem':
        return HasItem(reqString(m, 'id', ctx));
      case 'puzzleSolved':
        return PuzzleSolved(reqString(m, 'id', ctx));
      case 'flagAtLeast':
        return FlagAtLeast(reqString(m, 'id', ctx), reqInt(m, 'value', ctx));
      case 'flagEquals':
        return FlagEquals(reqString(m, 'id', ctx), reqInt(m, 'value', ctx));
      case 'exitOpen':
        return ExitOpen(reqString(m, 'id', ctx));
      case 'examined':
        return Examined(reqString(m, 'id', ctx));
      case 'choiceResolved':
        return ChoiceResolved(reqString(m, 'id', ctx));
      case 'visitedRoom':
        return VisitedRoom(reqString(m, 'id', ctx));
      case 'all':
        return All(_parseList(m, ctx));
      case 'any':
        return Any(_parseList(m, ctx));
      case 'not':
        return Not(Condition.fromJson(m['of'], '$ctx.of'));
      default:
        throw ContentFormatException('$ctx: unknown condition type "$type"');
    }
  }

  static List<Condition> _parseList(JsonMap m, String ctx) {
    final list = asList(m['of'], '$ctx.of');
    return [
      for (var i = 0; i < list.length; i++)
        Condition.fromJson(list[i], '$ctx.of[$i]'),
    ];
  }

  bool evaluate(ProgressView s);

  /// Direct sub-conditions (for combinators).
  List<Condition> get children => const [];

  /// This condition and all nested conditions.
  Iterable<Condition> flatten() sync* {
    yield this;
    for (final c in children) {
      yield* c.flatten();
    }
  }
}

final class Always extends Condition {
  const Always();
  @override
  bool evaluate(ProgressView s) => true;
}

final class HasItem extends Condition {
  const HasItem(this.id);
  final String id;
  @override
  bool evaluate(ProgressView s) => s.hasItem(id);
}

final class PuzzleSolved extends Condition {
  const PuzzleSolved(this.id);
  final String id;
  @override
  bool evaluate(ProgressView s) => s.puzzleSolved(id);
}

final class FlagAtLeast extends Condition {
  const FlagAtLeast(this.id, this.value);
  final String id;
  final int value;
  @override
  bool evaluate(ProgressView s) => s.flag(id) >= value;
}

final class FlagEquals extends Condition {
  const FlagEquals(this.id, this.value);
  final String id;
  final int value;
  @override
  bool evaluate(ProgressView s) => s.flag(id) == value;
}

final class ExitOpen extends Condition {
  const ExitOpen(this.id);
  final String id;
  @override
  bool evaluate(ProgressView s) => s.exitOpen(id);
}

final class Examined extends Condition {
  const Examined(this.id);
  final String id;
  @override
  bool evaluate(ProgressView s) => s.examined(id);
}

final class ChoiceResolved extends Condition {
  const ChoiceResolved(this.id);
  final String id;
  @override
  bool evaluate(ProgressView s) => s.choiceResolved(id);
}

final class VisitedRoom extends Condition {
  const VisitedRoom(this.id);
  final String id;
  @override
  bool evaluate(ProgressView s) => s.visitedRoom(id);
}

final class All extends Condition {
  const All(this.items);
  final List<Condition> items;
  @override
  List<Condition> get children => items;
  @override
  bool evaluate(ProgressView s) => items.every((c) => c.evaluate(s));
}

final class Any extends Condition {
  const Any(this.items);
  final List<Condition> items;
  @override
  List<Condition> get children => items;
  @override
  bool evaluate(ProgressView s) => items.any((c) => c.evaluate(s));
}

final class Not extends Condition {
  const Not(this.inner);
  final Condition inner;
  @override
  List<Condition> get children => [inner];
  @override
  bool evaluate(ProgressView s) => !inner.evaluate(s);
}
