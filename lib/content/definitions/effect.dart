import 'json_helpers.dart';

/// A state change declared in content JSON and applied by the game engine.
sealed class Effect {
  const Effect();

  factory Effect.fromJson(Object? json, [String ctx = 'effect']) {
    final m = asMap(json, ctx);
    final type = reqString(m, 'type', ctx);
    switch (type) {
      case 'giveItem':
        return GiveItem(reqString(m, 'id', ctx));
      case 'consumeItem':
        return ConsumeItem(reqString(m, 'id', ctx));
      case 'setFlag':
        return SetFlag(reqString(m, 'id', ctx), reqInt(m, 'value', ctx));
      case 'addFlag':
        return AddFlag(reqString(m, 'id', ctx), reqInt(m, 'amount', ctx));
      case 'openExit':
        return OpenExit(reqString(m, 'id', ctx));
      case 'startChoice':
        return StartChoice(reqString(m, 'id', ctx));
      default:
        throw ContentFormatException('$ctx: unknown effect type "$type"');
    }
  }

  static List<Effect> parseList(JsonMap m, String key, String ctx) {
    final raw = m[key];
    if (raw == null) return const [];
    final list = asList(raw, '$ctx.$key');
    return [
      for (var i = 0; i < list.length; i++)
        Effect.fromJson(list[i], '$ctx.$key[$i]'),
    ];
  }
}

final class GiveItem extends Effect {
  const GiveItem(this.id);
  final String id;
}

final class ConsumeItem extends Effect {
  const ConsumeItem(this.id);
  final String id;
}

final class SetFlag extends Effect {
  const SetFlag(this.id, this.value);
  final String id;
  final int value;
}

final class AddFlag extends Effect {
  const AddFlag(this.id, this.amount);
  final String id;
  final int amount;
}

final class OpenExit extends Effect {
  const OpenExit(this.id);
  final String id;
}

final class StartChoice extends Effect {
  const StartChoice(this.id);
  final String id;
}
