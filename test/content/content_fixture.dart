import 'dart:convert';
import 'dart:io';

import 'package:hauntquest/content/content_loader.dart';
import 'package:hauntquest/content/game_content.dart';
import 'package:hauntquest/content/validation/content_issue.dart';
import 'package:hauntquest/content/validation/content_validator.dart';

/// Reads the real content JSON files from disk as decoded maps.
Map<String, Object?> loadRawContent() => {
  for (final e in ContentLoader.assetPaths.entries)
    e.key: jsonDecode(File(e.value).readAsStringSync()),
};

/// A deep copy that tests can mutate freely.
Map<String, dynamic> freshRaw() =>
    jsonDecode(jsonEncode(loadRawContent())) as Map<String, dynamic>;

GameContent contentFrom(Map<String, dynamic> raw) =>
    GameContent.fromJson(raw.cast<String, Object?>());

ValidationReport validateRaw(Map<String, dynamic> raw) =>
    ContentValidator(contentFrom(raw)).validate();

List<dynamic> listIn(Map<String, dynamic> raw, String file, String key) =>
    (raw[file] as Map<String, dynamic>)[key] as List<dynamic>;

Map<String, dynamic> byId(List<dynamic> list, String id) =>
    list.cast<Map<String, dynamic>>().firstWhere((m) => m['id'] == id);

Map<String, dynamic> hotspotIn(Map<String, dynamic> raw, String id) {
  for (final room in listIn(
    raw,
    'rooms',
    'rooms',
  ).cast<Map<String, dynamic>>()) {
    for (final h in (room['hotspots'] as List).cast<Map<String, dynamic>>()) {
      if (h['id'] == id) return h;
    }
  }
  throw StateError('No hotspot $id');
}

Map<String, dynamic> exitIn(Map<String, dynamic> raw, String id) {
  for (final room in listIn(
    raw,
    'rooms',
    'rooms',
  ).cast<Map<String, dynamic>>()) {
    for (final e in (room['exits'] as List).cast<Map<String, dynamic>>()) {
      if (e['id'] == id) return e;
    }
  }
  throw StateError('No exit $id');
}
