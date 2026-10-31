import '../../content/game_content.dart';

/// A rule describing two items that can be joined together in the inventory.
class ItemCombinationRecipe {
  const ItemCombinationRecipe({
    required this.itemA,
    required this.itemB,
    required this.resultItemId,
    required this.successText,
    this.consumesItemA = true,
    this.consumesItemB = true,
    this.associatedPuzzleId,
  });

  final String itemA;
  final String itemB;
  final String resultItemId;
  final String successText;
  final bool consumesItemA;
  final bool consumesItemB;

  /// If this combination solves a known puzzle (such as the torn recipe puzzle).
  final String? associatedPuzzleId;

  /// Whether these two items match the recipe in either order.
  bool matches(String first, String second) =>
      (itemA == first && itemB == second) ||
      (itemA == second && itemB == first);
}

/// Catalog of combination recipes and feedback helpers.
class ItemCombinations {
  ItemCombinations._();

  /// Known valid item combination recipes.
  static const List<ItemCombinationRecipe> recipes = [
    ItemCombinationRecipe(
      itemA: 'torn_page_left',
      itemB: 'torn_page_right',
      resultItemId: 'silver_solvent',
      associatedPuzzleId: 'p4_torn_pages',
      successText:
          'The torn edges of the recipe meet and mend cleanly. The reunited '
          'instructions describe the Silver Solvent, and the damp ink reacts on '
          'the page, condensing into a cold vial of silver liquid.',
    ),
  ];

  /// Finds a matching recipe for two items in either order.
  static ItemCombinationRecipe? find(String itemA, String itemB) {
    if (itemA == itemB) return null;
    for (final r in recipes) {
      if (r.matches(itemA, itemB)) return r;
    }
    return null;
  }

  /// Provides helpful, in-world feedback when a combination fails.
  static String describeInvalid(GameContent content, String itemA, String itemB) {
    if (itemA == itemB) {
      return 'You cannot combine an item with itself.';
    }

    final hasPage = itemA == 'torn_page_left' ||
        itemA == 'torn_page_right' ||
        itemB == 'torn_page_left' ||
        itemB == 'torn_page_right';
    if (hasPage) {
      return 'This torn recipe fragment only aligns with its corresponding half.';
    }

    if (itemA == 'wrens_letter' || itemB == 'wrens_letter') {
      return "Wren's letter is delicate personal correspondence and cannot be combined with that.";
    }

    if (itemA == 'ottoline_journal' || itemB == 'ottoline_journal') {
      return "Ottoline's journal is fully bound. It has no slot or adhesive for that.";
    }

    if (itemA == 'brass_winding_key' || itemB == 'brass_winding_key') {
      return 'The brass winding key is shaped to turn an arbor, not to join with other carried items.';
    }

    if (itemA == 'tallow_lantern' || itemB == 'tallow_lantern') {
      return "The lantern's blue flame is sealed behind glass. Nothing can be combined into it.";
    }

    if (itemA == 'silver_solvent' || itemB == 'silver_solvent') {
      return 'The silver solvent is caustic and volatile; pour it on corroded metal rather than mixing it here.';
    }

    if (itemA == 'wax_cylinder' || itemB == 'wax_cylinder') {
      return 'The delicate wax cylinder must be placed in a phonograph, not joined with other items.';
    }

    if (itemA == 'spare_cog' || itemB == 'spare_cog') {
      return 'The spare cog is machined for a clockwork gear train and has no attachment for this.';
    }

    if (itemA == 'resonance_core' || itemB == 'resonance_core') {
      return 'The crystal core only resonates with the pillars of the Resonance Engine.';
    }

    return 'Those two items cannot be combined. They do not fit together.';
  }
}
