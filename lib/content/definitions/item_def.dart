import 'context_text.dart';
import 'json_helpers.dart';

/// A collectible object or clue.
class ItemDef {
  const ItemDef({
    required this.id,
    required this.name,
    required this.description,
    required this.detail,
    required this.iconId,
  });

  factory ItemDef.fromJson(JsonMap m, String ctx) => ItemDef(
    id: reqString(m, 'id', ctx),
    name: reqString(m, 'name', ctx),
    description: ContextText.fromJson(m['description'], '$ctx.description'),
    detail: ContextText.fromJson(m['detail'], '$ctx.detail'),
    iconId: reqString(m, 'iconId', ctx),
  );

  final String id;
  final String name;

  /// Short line shown in the inventory.
  final ContextText description;

  /// Full text shown when the item is inspected.
  final ContextText detail;
  final String iconId;
}
