import '../definitions/effect.dart';
import '../game_content.dart';

/// Builds a Mermaid flowchart of room and puzzle dependencies from content.
class ProgressionGraph {
  ProgressionGraph(this.content);

  final GameContent content;

  static String _id(String raw) =>
      raw.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  static String _label(String s) => s.replaceAll('"', "'");

  String toMermaid() {
    final b = StringBuffer('flowchart TD\n');

    // Rooms with their puzzles and item-giving hotspots.
    for (final room in content.rooms) {
      b.writeln('  subgraph ${_id('room_${room.id}')}["${_label(room.name)}"]');
      for (final h in room.hotspots) {
        final gives = h.onExamine.whereType<GiveItem>().isNotEmpty;
        if (gives) {
          b.writeln('    ${_id('hs_${h.id}')}("${_label(h.label)}")');
        }
      }
      for (final p in content.puzzles.where((p) => p.roomId == room.id)) {
        b.writeln('    ${_id('pz_${p.id}')}{{"${_label(p.title)}"}}');
      }
      b.writeln('  end');
    }

    // Start and endings.
    b.writeln('  start(["Arrive with Wren\'s letter"])');
    b.writeln('  start --> ${_id('room_${content.story.startRoomId}')}');
    for (final e in content.story.endings) {
      b.writeln('  ${_id('end_${e.id}')}[["${_label(e.title)}"]]');
    }

    // Choices.
    for (final c in content.choices) {
      b.writeln('  ${_id('ch_${c.id}')}>"Choice: ${_label(c.id)}"]');
    }

    String? producerNode(String itemId) {
      if (content.story.startItems.contains(itemId)) return 'start';
      for (final p in content.puzzles) {
        if (p.onSolved.whereType<GiveItem>().any((g) => g.id == itemId)) {
          return _id('pz_${p.id}');
        }
      }
      for (final h in content.allHotspots) {
        if (h.onExamine.whereType<GiveItem>().any((g) => g.id == itemId)) {
          return _id('hs_${h.id}');
        }
      }
      return null;
    }

    String itemName(String id) => _label(content.itemById(id)?.name ?? id);

    // Item flow into puzzles.
    for (final p in content.puzzles) {
      final target = _id('pz_${p.id}');
      for (final itemId in p.requiresItems) {
        final from = producerNode(itemId);
        if (from != null) {
          b.writeln('  $from -->|"${itemName(itemId)}"| $target');
        }
      }
      for (final clue in p.clues) {
        final sourceId = clue.sourceId;
        final from = clue.isItem
            ? producerNode(sourceId)
            : _id('room_${content.hotspotById(sourceId)?.roomId ?? ''}');
        if (from != null) b.writeln('  $from -.->|"clue"| $target');
      }
    }

    // Exits opened by puzzles.
    for (final p in content.puzzles) {
      for (final open in p.onSolved.whereType<OpenExit>()) {
        final exit = content.exitById(open.id);
        if (exit != null) {
          b.writeln(
            '  ${_id('pz_${p.id}')} ==>|"opens ${_label(exit.label)}"| ${_id('room_${exit.toRoomId}')}',
          );
        }
      }
      for (final start in p.onSolved.whereType<StartChoice>()) {
        b.writeln('  ${_id('pz_${p.id}')} --> ${_id('ch_${start.id}')}');
      }
    }

    // Hotspot-triggered choices.
    for (final h in content.allHotspots.where((h) => h.choiceId != null)) {
      b.writeln('  ${_id('room_${h.roomId}')} --> ${_id('ch_${h.choiceId}')}');
    }

    // Final choice to endings.
    for (final e in content.story.endings) {
      b.writeln(
        '  ${_id('ch_${content.story.finalChoiceId}')} -.->|"fate"| ${_id('end_${e.id}')}',
      );
    }
    return b.toString();
  }

  /// Plain-text list of mandatory puzzle prerequisites.
  String dependencyTable() {
    final b = StringBuffer(
      '| Puzzle | Room | Needs items | Needs clues from |\n|---|---|---|---|\n',
    );
    for (final p in content.puzzles) {
      final room = content.roomById(p.roomId)?.name ?? p.roomId;
      final items = p.requiresItems
          .map((i) => content.itemById(i)?.name ?? i)
          .join(', ');
      final clues = p.clues.map((c) => c.source).join(', ');
      b.writeln(
        '| ${p.title} | $room | ${items.isEmpty ? '-' : items} | ${clues.isEmpty ? '-' : clues} |',
      );
    }
    return b.toString();
  }
}
