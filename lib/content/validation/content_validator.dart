import '../definitions/condition.dart';
import '../definitions/context_text.dart';
import '../definitions/effect.dart';
import '../definitions/puzzle_def.dart';
import '../game_content.dart';
import 'content_issue.dart';
import 'dependency_analyzer.dart';
import 'progression_simulator.dart';

/// Validates authored content: identifiers, references, puzzle data, text
/// limits, and whole-game progression (rooms, items, puzzles, endings).
class ContentValidator {
  ContentValidator(this.content);

  final GameContent content;

  /// Mobile-friendly text limits (characters).
  static const int maxDescription = 320;
  static const int maxItemDetail = 460;
  static const int maxPrompt = 300;
  static const int maxOptionLabel = 80;
  static const int maxResult = 240;
  static const int maxHint = 200;
  static const int maxEpilogueLine = 200;
  static const int minHotspotsPerRoom = 3;

  /// Highest a hotspot may start on the 3:4 stage (fraction of its height)
  /// so its marker clears the status bar and the HUD buttons.
  static const double minHotspotTop = 0.12;

  final List<ContentIssue> _issues = [];

  ValidationReport validate() {
    _issues.clear();

    _checkUniqueIds();
    _checkStory();
    _checkRooms();
    _checkItems();
    _checkPuzzles();
    _checkChoices();
    _checkNarrative();
    _checkItemSupply();

    // Progression analysis only makes sense on structurally sound content.
    final structuralErrors = _issues.any(
      (i) => i.severity == IssueSeverity.error && _blocksProgression(i.code),
    );

    var routes = <EndingRoute>[];
    var playthroughs = 0;
    var order = <String>[];
    if (!structuralErrors) {
      final analyzer = DependencyAnalyzer(content);
      _issues.addAll(analyzer.analyze());
      order = analyzer.puzzleOrder;

      final sim = ProgressionSimulator(content);
      _issues.addAll(sim.run());
      routes = sim.endingRoutes();
      playthroughs = sim.leaves.length;
    }

    return ValidationReport(
      issues: List.unmodifiable(_issues),
      endingRoutes: routes,
      playthroughCount: playthroughs,
      dependencyOrder: order,
    );
  }

  static bool _blocksProgression(String code) =>
      code == 'duplicate_id' || code == 'unknown_reference';

  void _error(String code, String message) =>
      _issues.add(ContentIssue.error(code, message));

  // ------------------------------------------------------- unique ids

  void _checkUniqueIds() {
    void check(String kind, Iterable<String> ids) {
      final seen = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) _error('duplicate_id', 'Duplicate $kind id "$id".');
      }
    }

    check('room', content.rooms.map((r) => r.id));
    check('item', content.items.map((i) => i.id));
    check('puzzle', content.puzzles.map((p) => p.id));
    check('choice', content.choices.map((c) => c.id));
    check('hotspot', content.allHotspots.map((h) => h.id));
    check('exit', content.allExits.map((e) => e.id));
    check(
      'choice option',
      content.choices.expand((c) => c.options).map((o) => o.id),
    );
    check('ending', content.story.endings.map((e) => e.id));
    check('character', content.story.characters.map((c) => c.id));
    check('flag', content.story.flags.map((f) => f.id));
    check('journal entry', content.story.journalEntries.map((e) => e.id));
    check('evidence link', content.story.evidenceLinks.map((e) => e.id));
  }

  // ------------------------------------------------------- references

  void _ref(bool exists, String kind, String id, String where) {
    if (!exists) {
      _error('unknown_reference', '$where references unknown $kind "$id".');
    }
  }

  void _checkCondition(Condition? c, String where) {
    if (c == null) return;
    for (final n in c.flatten()) {
      switch (n) {
        case HasItem(:final id):
          _ref(content.itemById(id) != null, 'item', id, where);
        case PuzzleSolved(:final id):
          _ref(content.puzzleById(id) != null, 'puzzle', id, where);
        case FlagAtLeast(:final id, :final value):
          _checkFlagValue(id, value, where);
        case FlagEquals(:final id, :final value):
          _checkFlagValue(id, value, where);
        case ExitOpen(:final id):
          _ref(content.exitById(id) != null, 'exit', id, where);
        case Examined(:final id):
          _ref(content.hotspotById(id) != null, 'hotspot', id, where);
        case ChoiceResolved(:final id):
          _ref(content.choiceById(id) != null, 'choice', id, where);
        case VisitedRoom(:final id):
          _ref(content.roomById(id) != null, 'room', id, where);
        case Always() || All() || Any() || Not():
          break;
      }
    }
  }

  void _checkFlagValue(String id, int value, String where) {
    final def = content.flagById(id);
    _ref(def != null, 'flag', id, where);
    if (def != null && (value < def.min || value > def.max)) {
      _error(
        'flag_out_of_range',
        '$where compares flag "$id" to $value, outside ${def.min}..${def.max}.',
      );
    }
  }

  void _checkEffects(Iterable<Effect> effects, String where) {
    for (final e in effects) {
      switch (e) {
        case GiveItem(:final id) || ConsumeItem(:final id):
          _ref(content.itemById(id) != null, 'item', id, where);
        case SetFlag(:final id, :final value):
          final def = content.flagById(id);
          _ref(def != null, 'flag', id, where);
          if (def != null && (value < def.min || value > def.max)) {
            _error(
              'flag_out_of_range',
              '$where sets flag "$id" to $value, outside ${def.min}..${def.max}.',
            );
          }
        case AddFlag(:final id, :final amount):
          final def = content.flagById(id);
          _ref(def != null, 'flag', id, where);
          if (def != null && (amount <= 0 || amount > def.max)) {
            _error(
              'flag_out_of_range',
              '$where adds $amount to flag "$id" (range ${def.min}..${def.max}).',
            );
          }
        case OpenExit(:final id):
          _ref(content.exitById(id) != null, 'exit', id, where);
        case StartChoice(:final id):
          _ref(content.choiceById(id) != null, 'choice', id, where);
      }
    }
  }

  void _checkLength(String text, int max, String where) {
    if (text.length > max) {
      _error(
        'text_too_long',
        '$where is ${text.length} characters (limit $max) and may not read well on mobile.',
      );
    }
  }

  void _checkContextText(ContextText t, int max, String where) {
    for (final v in t.variants) {
      _checkCondition(v.when, '$where variant');
    }
    for (final text in t.allTexts) {
      _checkLength(text, max, where);
    }
  }

  // ------------------------------------------------------------ story

  void _checkStory() {
    final story = content.story;
    _ref(
      content.roomById(story.startRoomId) != null,
      'room',
      story.startRoomId,
      'story.startRoomId',
    );
    for (final id in story.startItems) {
      _ref(content.itemById(id) != null, 'item', id, 'story.startItems');
    }
    _ref(
      content.choiceById(story.finalChoiceId) != null,
      'choice',
      story.finalChoiceId,
      'story.finalChoiceId',
    );

    if (story.characters.length < 4) {
      _error(
        'too_few_characters',
        'Expected at least 4 characters or voices, found ${story.characters.length}.',
      );
    }
    if (story.endings.length != 3) {
      _error(
        'wrong_ending_count',
        'Expected exactly 3 endings, found ${story.endings.length}.',
      );
    }

    for (final f in story.flags) {
      if (f.min > f.max || f.initial < f.min || f.initial > f.max) {
        _error(
          'invalid_flag',
          'Flag "${f.id}" has an invalid range or initial value.',
        );
      }
    }
    for (final e in story.endings) {
      if (e.epilogue.isEmpty) {
        _error('empty_epilogue', 'Ending "${e.id}" has no epilogue text.');
      }
      for (final line in e.epilogue) {
        _checkLength(line, maxEpilogueLine, 'Ending "${e.id}" epilogue line');
      }
    }
    for (final line in story.introLines) {
      _checkLength(line, maxEpilogueLine, 'Intro line');
    }

    final rules = story.endingRules;
    if (rules.isEmpty) {
      _error('no_ending_rules', 'There are no ending rules.');
    } else {
      for (final r in rules) {
        _ref(
          content.endingById(r.endingId) != null,
          'ending',
          r.endingId,
          'ending rule',
        );
        _checkCondition(r.when, 'ending rule for "${r.endingId}"');
      }
      if (rules.last.when is! Always) {
        _error(
          'ending_rules_not_total',
          'The last ending rule must use an "always" condition so every outcome has an ending.',
        );
      }
    }
  }

  // ------------------------------------------------------------ rooms

  void _checkRooms() {
    if (content.rooms.length != 5) {
      _error(
        'wrong_room_count',
        'Expected exactly 5 rooms, found ${content.rooms.length}.',
      );
    }
    for (final room in content.rooms) {
      final where = 'Room "${room.id}"';
      _checkContextText(room.description, maxDescription, '$where description');
      if (room.hotspots.length < minHotspotsPerRoom) {
        _error(
          'too_few_hotspots',
          '$where has ${room.hotspots.length} hotspots (minimum $minHotspotsPerRoom).',
        );
      }
      for (final h in room.hotspots) {
        // The HUD buttons and the phone status bar cover the top of the
        // stage; objects there would be hidden or untappable.
        if (h.area.y < minHotspotTop) {
          _error(
            'hotspot_under_hud',
            '$where: hotspot "${h.id}" starts at y=${h.area.y}, under the HUD (minimum $minHotspotTop).',
          );
        }
      }
      for (var i = 0; i < room.hotspots.length; i++) {
        for (var j = i + 1; j < room.hotspots.length; j++) {
          final a = room.hotspots[i].area;
          final b = room.hotspots[j].area;
          final overlap =
              a.x < b.x + b.w &&
              b.x < a.x + a.w &&
              a.y < b.y + b.h &&
              b.y < a.y + a.h;
          if (overlap) {
            _error(
              'hotspot_overlap',
              '$where: hotspots "${room.hotspots[i].id}" and "${room.hotspots[j].id}" overlap, so taps would be ambiguous.',
            );
          }
        }
      }
      for (final exit in room.exits) {
        _ref(
          content.roomById(exit.toRoomId) != null,
          'room',
          exit.toRoomId,
          'Exit "${exit.id}"',
        );
        if (!exit.initiallyOpen && (exit.lockedText ?? '').isEmpty) {
          _error(
            'missing_locked_text',
            'Locked exit "${exit.id}" needs lockedText that explains the block.',
          );
        }
      }
      for (final h in room.hotspots) {
        final hw = 'Hotspot "${h.id}"';
        _checkCondition(h.requires, hw);
        _checkEffects(h.onExamine, hw);
        _checkContextText(h.description, maxDescription, '$hw description');
        _checkContextText(h.repeatText, maxDescription, '$hw repeat text');
        if (!h.area.isWithinUnitSquare) {
          _error(
            'invalid_hotspot_area',
            '$hw area must lie inside the 0 to 1 scene square.',
          );
        }
        if (h.requires != null && (h.lockedText ?? '').isEmpty) {
          _error(
            'missing_locked_text',
            '$hw has a requirement but no lockedText to explain it.',
          );
        }
        if (h.puzzleId != null) {
          final p = content.puzzleById(h.puzzleId!);
          _ref(p != null, 'puzzle', h.puzzleId!, hw);
          if (p != null && p.hotspotId != h.id) {
            _error(
              'puzzle_hotspot_mismatch',
              '$hw points to puzzle "${p.id}", but that puzzle points to hotspot "${p.hotspotId}".',
            );
          }
        }
        if (h.choiceId != null) {
          _ref(
            content.choiceById(h.choiceId!) != null,
            'choice',
            h.choiceId!,
            hw,
          );
        }
        for (final rule in h.useRules) {
          final rw = '$hw use rule for "${rule.itemId}"';
          _ref(content.itemById(rule.itemId) != null, 'item', rule.itemId, rw);
          _checkCondition(rule.when, rw);
          _checkEffects(rule.effects, rw);
          _checkLength(rule.successText, maxResult, rw);
        }
      }
    }
  }

  // ------------------------------------------------------------ items

  void _checkItems() {
    for (final item in content.items) {
      _checkContextText(
        item.description,
        maxDescription,
        'Item "${item.id}" description',
      );
      _checkContextText(item.detail, maxItemDetail, 'Item "${item.id}" detail');
    }
  }

  /// Every item that something needs must be given by something; consumable
  /// items must have exactly one consumer so greedy simulation stays sound.
  void _checkItemSupply() {
    final supplied = <String>{
      ...content.story.startItems,
      for (final p in content.puzzles) ..._givenBy(p.onSolved),
      for (final h in content.allHotspots) ...[
        ..._givenBy(h.onExamine),
        for (final r in h.useRules) ..._givenBy(r.effects),
      ],
      for (final c in content.choices)
        for (final o in c.options) ..._givenBy(o.effects),
    };

    final needed = <String, String>{}; // item -> first place that needs it
    for (final p in content.puzzles) {
      for (final id in p.requiresItems) {
        needed.putIfAbsent(id, () => 'puzzle "${p.id}"');
      }
    }
    for (final h in content.allHotspots) {
      for (final r in h.useRules) {
        needed.putIfAbsent(r.itemId, () => 'hotspot "${h.id}" use rule');
      }
    }
    for (final entry in needed.entries) {
      if (content.itemById(entry.key) != null &&
          !supplied.contains(entry.key)) {
        _error(
          'item_never_granted',
          'Item "${entry.key}" is required by ${entry.value} but nothing ever grants it.',
        );
      }
    }

    final consumers = <String, int>{};
    void consume(String id) =>
        consumers.update(id, (c) => c + 1, ifAbsent: () => 1);
    for (final p in content.puzzles) {
      p.consumesItems.forEach(consume);
      for (final e in p.onSolved.whereType<ConsumeItem>()) {
        consume(e.id);
      }
    }
    for (final h in content.allHotspots) {
      for (final r in h.useRules) {
        if (r.consumeItem) consume(r.itemId);
      }
    }
    for (final e in consumers.entries) {
      if (e.value > 1) {
        _error(
          'item_multiple_consumers',
          'Item "${e.key}" is consumed in ${e.value} places; consumable items need exactly one consumer.',
        );
      }
    }
  }

  static Iterable<String> _givenBy(Iterable<Effect> effects) =>
      effects.whereType<GiveItem>().map((e) => e.id);

  // ---------------------------------------------------------- puzzles

  void _checkPuzzles() {
    if (content.puzzles.length < 8) {
      _error(
        'wrong_puzzle_count',
        'Expected at least 8 puzzles, found ${content.puzzles.length}.',
      );
    }
    for (final p in content.puzzles) {
      final where = 'Puzzle "${p.id}"';
      final room = content.roomById(p.roomId);
      _ref(room != null, 'room', p.roomId, where);
      final hotspot = content.hotspotById(p.hotspotId);
      _ref(hotspot != null, 'hotspot', p.hotspotId, where);
      if (hotspot != null && hotspot.roomId != p.roomId) {
        _error(
          'puzzle_room_mismatch',
          '$where is in room "${p.roomId}" but its hotspot is in "${hotspot.roomId}".',
        );
      }
      if (hotspot != null && hotspot.puzzleId != p.id) {
        _error(
          'puzzle_hotspot_mismatch',
          '$where names hotspot "${hotspot.id}", but that hotspot does not open this puzzle.',
        );
      }
      _checkCondition(p.unlockWhen, where);
      _checkEffects(p.onSolved, where);

      for (final id in p.requiresItems) {
        _ref(content.itemById(id) != null, 'item', id, '$where requiresItems');
      }
      for (final id in p.consumesItems) {
        _ref(content.itemById(id) != null, 'item', id, '$where consumesItems');
        if (!p.requiresItems.contains(id)) {
          _error(
            'invalid_item_requirement',
            '$where consumes "$id" but does not require it.',
          );
        }
      }

      _checkLength(p.intro, maxResult, '$where intro');
      _checkLength(p.successText, maxResult, '$where successText');
      _checkLength(p.incorrectText, maxResult, '$where incorrectText');

      _checkHints(p, where);
      _checkClues(p, where);
      _checkConfig(p, where);
    }
  }

  void _checkHints(PuzzleDef p, String where) {
    if (p.hints.length != 3) {
      _error(
        'wrong_hint_count',
        '$where has ${p.hints.length} hint tiers; exactly 3 are required.',
      );
    }
    for (final (i, h) in p.hints.indexed) {
      if (h.trim().isEmpty) {
        _error('empty_hint', '$where hint tier ${i + 1} is empty.');
      }
      _checkLength(h, maxHint, '$where hint tier ${i + 1}');
    }
    // Tiers 1 and 2 must not give away a typed answer.
    if (p.kind == PuzzleKind.cipher && p.hints.length >= 2) {
      final answer = (p.config['answer'] as String? ?? '').toLowerCase();
      if (answer.isNotEmpty) {
        for (var i = 0; i < 2; i++) {
          if (p.hints[i].toLowerCase().contains(answer)) {
            _error(
              'hint_spoils_answer',
              '$where hint tier ${i + 1} reveals the answer; only tier 3 may.',
            );
          }
        }
      }
    }
  }

  void _checkClues(PuzzleDef p, String where) {
    final needsClue = {
      PuzzleKind.cipher,
      PuzzleKind.dial,
      PuzzleKind.clock,
      PuzzleKind.gears,
      PuzzleKind.sequence,
    }.contains(p.kind);
    if (needsClue && p.clues.isEmpty) {
      _error(
        'missing_clue',
        '$where is a ${p.kind.name} puzzle but declares no clue sources, so players cannot deduce the answer.',
      );
    }
    for (final clue in p.clues) {
      Iterable<String>? texts;
      if (clue.isItem) {
        final item = content.itemById(clue.sourceId);
        _ref(item != null, 'item', clue.sourceId, '$where clue');
        texts = item == null
            ? null
            : [...item.description.allTexts, ...item.detail.allTexts];
      } else if (clue.isHotspot) {
        final h = content.hotspotById(clue.sourceId);
        _ref(h != null, 'hotspot', clue.sourceId, '$where clue');
        texts = h == null
            ? null
            : [
                ...h.description.allTexts,
                ...h.repeatText.allTexts,
                for (final r in h.useRules) r.successText,
              ];
      } else {
        _error(
          'invalid_clue_source',
          '$where clue source "${clue.source}" must start with "item:" or "hotspot:".',
        );
      }
      if (texts != null) {
        final needle = clue.contains.toLowerCase();
        if (!texts.any((t) => t.toLowerCase().contains(needle))) {
          _error(
            'clue_text_missing',
            '$where expects "${clue.contains}" in ${clue.source}, but that text does not appear.',
          );
        }
      }
    }
  }

  void _checkConfig(PuzzleDef p, String where) {
    void bad(String why) => _error('invalid_puzzle_config', '$where: $why');
    final c = p.config;

    switch (p.kind) {
      case PuzzleKind.sequence:
        final options = _strings(c['options']);
        final solution = _strings(c['solution']);
        if (options == null || solution == null || solution.isEmpty) {
          bad(
            'sequence needs "options" and a non-empty "solution" list of strings.',
          );
          return;
        }
        if (options.toSet().length != options.length) {
          bad('options contain duplicates.');
        }
        if (solution.toSet().length != solution.length) {
          bad('solution repeats an option.');
        }
        if (c['variant'] == 'echo') {
          final frequencies = c['frequencies'];
          if (frequencies is! List ||
              frequencies.map((v) => '$v').join(',') != solution.join(',')) {
            bad('echo playback must match the solution frequencies.');
          }
        }
        if (!solution.every(options.contains)) {
          bad('solution uses an unknown option.');
        }
      case PuzzleKind.cipher:
        final text = c['cipherText'];
        final answer = c['answer'];
        if (c['variant'] == 'symbols') {
          final alphabet = c['substitution'];
          if (text is! String ||
              answer is! String ||
              alphabet is! Map ||
              alphabet.isEmpty ||
              alphabet.values.any((v) => v is! String || v.length != 1) ||
              alphabet.values.toSet().length != alphabet.length) {
            bad('symbol cipher needs a one-to-one substitution alphabet.');
            return;
          }
          final symbols = text.split(' ');
          if (symbols.any((s) => !alphabet.containsKey(s)) ||
              symbols.map((s) => alphabet[s]).join() != answer) {
            bad('symbol cipher does not decode to its answer.');
          }
          return;
        }
        final shift = c['shift'];
        if (text is! String || answer is! String || shift is! int) {
          bad(
            'cipher needs string "cipherText", string "answer", and integer "shift".',
          );
          return;
        }
        if (_shiftText(answer, shift) != text.toUpperCase()) {
          bad(
            'cipherText "$text" does not decode to "$answer" with shift $shift.',
          );
        }
      case PuzzleKind.dial:
        final min = c['min'],
            max = c['max'],
            target = c['target'],
            start = c['start'];
        if (min is! int || max is! int || target is! int || start is! int) {
          bad('dial needs integer "min", "max", "start", and "target".');
          return;
        }
        if (min >= max) bad('dial min must be below max.');
        if (target < min || target > max) {
          bad('dial target $target is outside $min..$max.');
        }
        if (start < min || start > max) {
          bad('dial start $start is outside $min..$max.');
        }
        if (start == target) bad('dial starts on the answer.');
      case PuzzleKind.combine:
        final slots = _strings(c['slots']);
        if (slots == null || slots.length < 2) {
          bad('combine needs at least 2 "slots".');
          return;
        }
        for (final s in slots) {
          _ref(content.itemById(s) != null, 'item', s, '$where slot');
          if (!p.requiresItems.contains(s)) {
            _error(
              'invalid_item_requirement',
              '$where slot "$s" is not listed in requiresItems.',
            );
          }
        }
      case PuzzleKind.useItem:
        final itemId = c['itemId'], hotspotId = c['hotspotId'];
        if (itemId is! String || hotspotId is! String) {
          bad('useItem needs string "itemId" and "hotspotId".');
          return;
        }
        _ref(
          content.itemById(itemId) != null,
          'item',
          itemId,
          '$where useItem',
        );
        if (hotspotId != p.hotspotId) {
          bad('useItem hotspotId must equal the puzzle hotspot.');
        }
        if (!p.requiresItems.contains(itemId)) {
          _error(
            'invalid_item_requirement',
            '$where uses "$itemId" but does not list it in requiresItems.',
          );
        }
      case PuzzleKind.clock:
        final h = c['hour'], m = c['minute'];
        if (h is! int || m is! int) {
          bad('clock needs integer "hour" and "minute".');
          return;
        }
        if (h < 1 || h > 12) bad('hour must be 1 to 12.');
        if (m < 0 || m > 59) bad('minute must be 0 to 59.');
      case PuzzleKind.gears:
        final positions = c['positions'];
        final target = c['target'];
        if (positions is! int ||
            positions < 2 ||
            target is! List ||
            target.isEmpty) {
          bad(
            'gears needs integer "positions" (2 or more) and a non-empty "target" list.',
          );
          return;
        }
        if (!target.every((t) => t is int && t >= 0 && t < positions)) {
          bad('gear targets must be integers from 0 to ${positions - 1}.');
        }
        if (c['variant'] == 'mirror') {
          final source = c['source'];
          if (positions != 2 ||
              c['columns'] != 3 ||
              source is! List ||
              source.length != 9 ||
              target.length != 9 ||
              source.any((v) => v != 0 && v != 1)) {
            bad('mirror needs a binary 3 by 3 source and reflection.');
            return;
          }
          for (var i = 0; i < 9; i++) {
            if (target[i] != source[(i ~/ 3) * 3 + 2 - i % 3]) {
              bad('mirror target must reverse columns in each source row.');
              break;
            }
          }
        }
        if (c['variant'] == 'constellation' &&
            (positions != 4 ||
                _strings(c['labels'])?.length != target.length)) {
          bad(
            'constellation needs four compass positions and a label for each disc.',
          );
        }
        if (target.every((t) => t == 0)) {
          bad('gears start solved (all targets are 0).');
        }
    }
  }

  static List<String>? _strings(Object? v) =>
      v is List && v.every((e) => e is String) ? v.cast<String>() : null;

  /// Caesar-shifts [text] forward by [shift] letters, uppercase A to Z only.
  static String _shiftText(String text, int shift) {
    final buffer = StringBuffer();
    for (final unit in text.toUpperCase().codeUnits) {
      if (unit >= 65 && unit <= 90) {
        buffer.writeCharCode(65 + (unit - 65 + shift) % 26);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  void _checkNarrative() {
    final ids = content.story.journalEntries.map((e) => e.id).toSet();
    for (final entry in content.story.journalEntries) {
      _checkCondition(entry.unlockWhen, 'Journal "${entry.id}"');
      _checkContextText(entry.text, maxItemDetail, 'Journal "${entry.id}"');
      _checkLength(entry.title, maxOptionLabel, 'Journal title');
    }
    for (final link in content.story.evidenceLinks) {
      _ref(
        ids.contains(link.from),
        'journal entry',
        link.from,
        'Evidence "${link.id}"',
      );
      _ref(
        ids.contains(link.to),
        'journal entry',
        link.to,
        'Evidence "${link.id}"',
      );
      if (link.from == link.to) {
        _error(
          'evidence_self_link',
          'Evidence "${link.id}" connects an entry to itself.',
        );
      }
      _checkCondition(link.requires, 'Evidence "${link.id}"');
      _checkLength(link.label, maxResult, 'Evidence "${link.id}"');
    }
    for (final ending in content.story.endings) {
      if (!{'release', 'seal', 'guardian'}.contains(ending.revealStyle)) {
        _error(
          'invalid_reveal',
          'Ending "${ending.id}" has unknown reveal style.',
        );
      }
    }
    // Check every node, including unreferenced subgraphs. One-shot execution is
    // also enforced by the engine, but authored continuations must be acyclic.
    final edges = <String, Set<String>>{
      for (final c in content.choices)
        c.id: {
          for (final o in c.options)
            if (o.nextChoiceId != null) o.nextChoiceId!,
          for (final o in c.options)
            for (final e in o.effects)
              if (e is StartChoice) e.id,
        },
    };
    final active = <String>{};
    final done = <String>{};
    void visit(String id) {
      if (done.contains(id)) return;
      if (!active.add(id)) {
        _error('dialogue_cycle', 'Dialogue continuation cycle includes "$id".');
        return;
      }
      for (final next in edges[id] ?? <String>{}) {
        visit(next);
      }
      active.remove(id);
      done.add(id);
    }

    for (final id in edges.keys) {
      visit(id);
    }
  }

  // ---------------------------------------------------------- choices

  void _checkChoices() {
    if (content.choices.length < 3) {
      _error(
        'too_few_choices',
        'Expected at least 3 dialogue choices, found ${content.choices.length}.',
      );
    }
    for (final c in content.choices) {
      final where = 'Choice "${c.id}"';
      _ref(
        content.characterById(c.speakerId) != null,
        'character',
        c.speakerId,
        where,
      );
      _checkCondition(c.requires, where);
      if (c.roomId != null) {
        _ref(content.roomById(c.roomId!) != null, 'room', c.roomId!, where);
      }
      _checkContextText(c.prompt, maxPrompt, '$where prompt');
      if (c.options.length < 2) {
        _error('too_few_options', '$where needs at least 2 options.');
      }
      for (final o in c.options) {
        final ow = '$where option "${o.id}"';
        _checkCondition(o.enabledWhen, ow);
        _checkEffects(o.effects, ow);
        if (c.id == content.story.finalChoiceId &&
            o.effects.any((e) => e is StartChoice)) {
          _error(
            'ending_continues',
            '$ow starts another scene after the final decision.',
          );
        }
        if (o.nextChoiceId case final id?) {
          _ref(content.choiceById(id) != null, 'choice', id, ow);
          if (c.id == content.story.finalChoiceId) {
            _error(
              'ending_continues',
              '$ow continues after the final decision.',
            );
          }
        }
        if (o.reaction case final reaction?) {
          _checkContextText(reaction, maxResult, '$ow reaction');
        }
        _checkLength(o.label, maxOptionLabel, '$ow label');
        _checkLength(o.resultText, maxResult, '$ow result');
        if (o.enabledWhen != null && (o.disabledReason ?? '').isEmpty) {
          _error(
            'missing_disabled_reason',
            '$ow can be disabled but gives no reason.',
          );
        }
      }
    }
  }
}
