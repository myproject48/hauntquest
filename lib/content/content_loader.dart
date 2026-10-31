import 'dart:convert';

import 'game_content.dart';

/// Loads and parses the bundled content files.
///
/// The reader is injected so this stays free of Flutter imports. In the app,
/// pass `rootBundle.loadString`; in tools and tests, read from disk.
class ContentLoader {
  const ContentLoader._();

  /// Asset paths for each content document.
  static const Map<String, String> assetPaths = {
    'story': 'assets/content/story.json',
    'rooms': 'assets/content/rooms.json',
    'items': 'assets/content/items.json',
    'puzzles': 'assets/content/puzzles.json',
    'choices': 'assets/content/choices.json',
  };

  static Future<GameContent> load(
    Future<String> Function(String path) read,
  ) async {
    final files = <String, Object?>{};
    for (final entry in assetPaths.entries) {
      files[entry.key] = jsonDecode(await read(entry.value));
    }
    return GameContent.fromJson(files);
  }
}
