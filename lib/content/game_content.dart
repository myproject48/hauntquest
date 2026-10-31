import 'definitions/choice_def.dart';
import 'definitions/item_def.dart';
import 'definitions/json_helpers.dart';
import 'definitions/progress_view.dart';
import 'definitions/puzzle_def.dart';
import 'definitions/room_def.dart';
import 'definitions/story_def.dart';

/// All authored game content, parsed from the JSON assets.
///
/// Lists keep authored order (and any duplicates, so the validator can report
/// them). Lookups return the first definition with a given id.
class GameContent {
  GameContent({
    required this.story,
    required this.rooms,
    required this.items,
    required this.puzzles,
    required this.choices,
  });

  /// Builds content from decoded JSON documents keyed by [fileKeys].
  factory GameContent.fromJson(Map<String, Object?> files) {
    JsonMap file(String key) => asMap(files[key], 'file "$key"');
    final roomsFile = file('rooms');
    final itemsFile = file('items');
    final puzzlesFile = file('puzzles');
    final choicesFile = file('choices');
    return GameContent(
      story: StoryDef.fromJson(file('story')),
      rooms: [
        for (final (i, r) in objectList(roomsFile, 'rooms', 'rooms').indexed)
          RoomDef.fromJson(r, 'rooms[$i]'),
      ],
      items: [
        for (final (i, r) in objectList(itemsFile, 'items', 'items').indexed)
          ItemDef.fromJson(r, 'items[$i]'),
      ],
      puzzles: [
        for (final (i, r) in objectList(
          puzzlesFile,
          'puzzles',
          'puzzles',
        ).indexed)
          PuzzleDef.fromJson(r, 'puzzles[$i]'),
      ],
      choices: [
        for (final (i, r) in objectList(
          choicesFile,
          'choices',
          'choices',
        ).indexed)
          ChoiceDef.fromJson(r, 'choices[$i]'),
      ],
    );
  }

  /// Keys expected in the map passed to [GameContent.fromJson].
  static const List<String> fileKeys = [
    'story',
    'rooms',
    'items',
    'puzzles',
    'choices',
  ];

  final StoryDef story;
  final List<RoomDef> rooms;
  final List<ItemDef> items;
  final List<PuzzleDef> puzzles;
  final List<ChoiceDef> choices;

  late final Map<String, RoomDef> _roomIndex = _index(rooms, (r) => r.id);
  late final Map<String, ItemDef> _itemIndex = _index(items, (r) => r.id);
  late final Map<String, PuzzleDef> _puzzleIndex = _index(puzzles, (r) => r.id);
  late final Map<String, ChoiceDef> _choiceIndex = _index(choices, (r) => r.id);
  late final Map<String, HotspotDef> _hotspotIndex = _index(
    allHotspots.toList(),
    (r) => r.id,
  );
  late final Map<String, ExitDef> _exitIndex = _index(
    allExits.toList(),
    (r) => r.id,
  );
  late final Map<String, EndingDef> _endingIndex = _index(
    story.endings,
    (r) => r.id,
  );
  late final Map<String, CharacterDef> _characterIndex = _index(
    story.characters,
    (r) => r.id,
  );
  late final Map<String, FlagDef> _flagIndex = _index(story.flags, (r) => r.id);

  RoomDef? roomById(String id) => _roomIndex[id];
  ItemDef? itemById(String id) => _itemIndex[id];
  PuzzleDef? puzzleById(String id) => _puzzleIndex[id];
  ChoiceDef? choiceById(String id) => _choiceIndex[id];
  HotspotDef? hotspotById(String id) => _hotspotIndex[id];
  ExitDef? exitById(String id) => _exitIndex[id];
  EndingDef? endingById(String id) => _endingIndex[id];
  CharacterDef? characterById(String id) => _characterIndex[id];
  FlagDef? flagById(String id) => _flagIndex[id];

  Iterable<HotspotDef> get allHotspots => rooms.expand((r) => r.hotspots);
  Iterable<ExitDef> get allExits => rooms.expand((r) => r.exits);

  /// Picks the ending using the ordered rules, or null if no rule matches.
  /// Depends only on story flags, never on randomness or time.
  String? resolveEnding(ProgressView progress) {
    for (final rule in story.endingRules) {
      if (rule.when.evaluate(progress)) return rule.endingId;
    }
    return null;
  }

  static Map<String, T> _index<T>(List<T> list, String Function(T) idOf) => {
    for (final e in list.reversed) idOf(e): e,
  };
}
