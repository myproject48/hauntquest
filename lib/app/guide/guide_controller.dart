import 'package:flutter/foundation.dart';

import '../../domain/guide/guide_models.dart';
import '../../domain/guide/guide_service.dart';
import '../../domain/models/game_state.dart';

/// Companion-only presentation state. Deliberately has no GameController,
/// GameEngine, GameStore, inventory or narrative mutation capability.
class GuideController extends ChangeNotifier {
  GuideController(this.service);
  final GuideService service;
  final Map<String, int> _levels = {};
  final Map<String, GuideReply> _replies = {};
  GameState? _snapshot;
  int _generation = 0;
  bool _disposed = false;
  bool _busy = false;
  bool _useAi = false;
  String _topicId = 'room';
  GuideReply? _reply;

  String get topicId => _topicId;
  GuideReply? get reply => _reply;
  bool get busy => _busy;
  bool get useAi => _useAi;
  int get revealedLevels => _levels[_topicId] ?? 0;
  bool get directShown => revealedLevels >= HintLevel.values.length;

  /// Invalidate pending assistance and obsolete hints as the real game changes.
  /// Equality includes discoveries, choices, drafts and room, not just time.
  void sync(GameState state) {
    if (_snapshot == state) return;
    _snapshot = state;
    _generation++;
    _busy = false;
    _reply = null;
    _levels.clear();
    _replies.clear();
    if (!service.offline.topics(state).any((t) => t.id == _topicId)) {
      _topicId = 'room';
    }
    notifyListeners();
  }

  void selectTopic(String id, GameState state) {
    sync(state);
    if (!service.offline.topics(state).any((t) => t.id == id) ||
        id == _topicId) {
      return;
    }
    _generation++;
    _topicId = id;
    _reply = _replies[id];
    _busy = false;
    notifyListeners();
  }

  void setUseAi(bool value) {
    _generation++;
    _useAi = value && service.aiConfigured;
    _busy = false;
    // Existing AI labeling must not survive disabling optional assistance.
    if (!_useAi && _snapshot != null) {
      for (final entry in _levels.entries) {
        final plan = service.offline.plan(
          _snapshot!,
          topicId: entry.key,
          level: HintLevel.values[entry.value - 1],
        );
        _replies[entry.key] = GuideReply(
          text: plan.offlineText,
          level: plan.level,
        );
      }
      _reply = _replies[_topicId];
    }
    notifyListeners();
  }

  Future<void> ask(GameState state) async {
    sync(state);
    if (_busy || directShown) return;
    final level = HintLevel.values[revealedLevels];
    _levels[_topicId] = level.index + 1;
    final plan = service.offline.plan(state, topicId: _topicId, level: level);
    // Offline help is immediately available, even while assistance is pending.
    _reply = GuideReply(text: plan.offlineText, level: level);
    _replies[_topicId] = _reply!;
    _busy = _useAi && service.aiConfigured;
    final generation = ++_generation;
    notifyListeners();
    final result = await service.reply(plan, useAi: _useAi);
    if (_disposed || generation != _generation || _snapshot != state) return;
    _reply = result;
    _replies[_topicId] = result;
    _busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
