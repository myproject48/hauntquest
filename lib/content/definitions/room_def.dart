import 'condition.dart';
import 'context_text.dart';
import 'effect.dart';
import 'json_helpers.dart';

/// Normalized (0 to 1) rectangle of a hotspot inside its room scene.
class HotspotArea {
  const HotspotArea({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory HotspotArea.fromJson(Object? json, String ctx) {
    final m = asMap(json, ctx);
    return HotspotArea(
      x: reqDouble(m, 'x', ctx),
      y: reqDouble(m, 'y', ctx),
      w: reqDouble(m, 'w', ctx),
      h: reqDouble(m, 'h', ctx),
    );
  }

  final double x;
  final double y;
  final double w;
  final double h;

  bool get isWithinUnitSquare =>
      x >= 0 && y >= 0 && w > 0 && h > 0 && x + w <= 1 && y + h <= 1;
}

/// Applying an inventory item to a hotspot.
class UseRule {
  const UseRule({
    required this.itemId,
    required this.successText,
    this.when,
    this.effects = const [],
    this.consumeItem = false,
  });

  factory UseRule.fromJson(JsonMap m, String ctx) => UseRule(
    itemId: reqString(m, 'itemId', ctx),
    successText: reqString(m, 'successText', ctx),
    when: m['when'] == null ? null : Condition.fromJson(m['when'], '$ctx.when'),
    effects: Effect.parseList(m, 'effects', ctx),
    consumeItem: optBool(m, 'consumeItem', ctx),
  );

  final String itemId;
  final String successText;
  final Condition? when;
  final List<Effect> effects;
  final bool consumeItem;
}

/// An interactable object in a room.
class HotspotDef {
  const HotspotDef({
    required this.id,
    required this.roomId,
    required this.label,
    required this.semanticLabel,
    required this.area,
    required this.description,
    required this.repeatText,
    this.requires,
    this.lockedText,
    this.onExamine = const [],
    this.useRules = const [],
    this.wrongItemText =
        'You try it, but nothing happens. The idea was not quite right.',
    this.puzzleId,
    this.choiceId,
  });

  factory HotspotDef.fromJson(JsonMap m, String roomId, String ctx) {
    final description = ContextText.fromJson(
      m['description'],
      '$ctx.description',
    );
    return HotspotDef(
      id: reqString(m, 'id', ctx),
      roomId: roomId,
      label: reqString(m, 'label', ctx),
      semanticLabel: reqString(m, 'semanticLabel', ctx),
      area: HotspotArea.fromJson(m['area'], '$ctx.area'),
      description: description,
      repeatText: m['repeatText'] == null
          ? description
          : ContextText.fromJson(m['repeatText'], '$ctx.repeatText'),
      requires: m['requires'] == null
          ? null
          : Condition.fromJson(m['requires'], '$ctx.requires'),
      lockedText: optString(m, 'lockedText', ctx),
      onExamine: Effect.parseList(m, 'onExamine', ctx),
      useRules: [
        for (final (i, r) in objectList(
          m,
          'useRules',
          ctx,
          required: false,
        ).indexed)
          UseRule.fromJson(r, '$ctx.useRules[$i]'),
      ],
      wrongItemText:
          optString(m, 'wrongItemText', ctx) ??
          'You try it, but nothing happens. The idea was not quite right.',
      puzzleId: optString(m, 'puzzleId', ctx),
      choiceId: optString(m, 'choiceId', ctx),
    );
  }

  final String id;
  final String roomId;
  final String label;
  final String semanticLabel;
  final HotspotArea area;

  /// Shown the first time the hotspot is examined.
  final ContextText description;

  /// Shown on later examinations.
  final ContextText repeatText;

  /// Condition that must hold to interact. Otherwise [lockedText] is shown.
  final Condition? requires;
  final String? lockedText;

  /// Effects applied once, on the first successful examination.
  final List<Effect> onExamine;
  final List<UseRule> useRules;
  final String wrongItemText;
  final String? puzzleId;
  final String? choiceId;
}

/// A passage from one room to another.
class ExitDef {
  const ExitDef({
    required this.id,
    required this.fromRoomId,
    required this.toRoomId,
    required this.label,
    required this.initiallyOpen,
    this.lockedText,
  });

  factory ExitDef.fromJson(JsonMap m, String fromRoomId, String ctx) => ExitDef(
    id: reqString(m, 'id', ctx),
    fromRoomId: fromRoomId,
    toRoomId: reqString(m, 'toRoomId', ctx),
    label: reqString(m, 'label', ctx),
    initiallyOpen: optBool(m, 'initiallyOpen', ctx),
    lockedText: optString(m, 'lockedText', ctx),
  );

  final String id;
  final String fromRoomId;
  final String toRoomId;
  final String label;
  final bool initiallyOpen;
  final String? lockedText;
}

/// One explorable location.
class RoomDef {
  const RoomDef({
    required this.id,
    required this.name,
    required this.description,
    required this.ambientCue,
    required this.sceneId,
    required this.mood,
    required this.hotspots,
    required this.exits,
  });

  factory RoomDef.fromJson(JsonMap m, String ctx) {
    final id = reqString(m, 'id', ctx);
    return RoomDef(
      id: id,
      name: reqString(m, 'name', ctx),
      description: ContextText.fromJson(m['description'], '$ctx.description'),
      ambientCue: reqString(m, 'ambientCue', ctx),
      sceneId: reqString(m, 'sceneId', ctx),
      mood: reqString(m, 'mood', ctx),
      hotspots: [
        for (final (i, h) in objectList(m, 'hotspots', ctx).indexed)
          HotspotDef.fromJson(h, id, '$ctx.hotspots[$i]'),
      ],
      exits: [
        for (final (i, e) in objectList(m, 'exits', ctx).indexed)
          ExitDef.fromJson(e, id, '$ctx.exits[$i]'),
      ],
    );
  }

  final String id;
  final String name;
  final ContextText description;
  final String ambientCue;
  final String sceneId;

  /// Name of the [AppColors] accent that dominates the room.
  final String mood;
  final List<HotspotDef> hotspots;
  final List<ExitDef> exits;
}
