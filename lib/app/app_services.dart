import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/content_loader.dart';
import '../content/game_content.dart';
import '../content/validation/content_validator.dart';
import '../domain/guide/guide_service.dart';
import '../domain/guide/guide_provider.dart';
import '../domain/guide/offline_guide.dart';
import 'game_controller.dart';
import 'game_store.dart';
import 'settings_controller.dart';
import 'audio/audio_backend.dart';
import 'audio/audio_director.dart';
import 'audio/local_audio_backend.dart';

/// Thrown at startup when the bundled content fails validation.
class ContentValidationException implements Exception {
  ContentValidationException(this.details);

  final String details;

  @override
  String toString() => 'The story content is invalid:\n$details';
}

/// Everything the screens share. Created once at startup.
class AppServices {
  AppServices({
    required this.content,
    required this.settings,
    required this.game,
    GuideService? guide,
    AudioBackend? audioBackend,
  }) : guide = guide ?? GuideService(offline: OfflineGuide(content)) {
    audio = AudioDirector(
      game: game,
      settings: settings,
      backend: audioBackend ?? SilentAudioBackend(),
    );
  }

  final GameContent content;
  final SettingsController settings;
  final GameController game;
  final GuideService guide;
  late final AudioDirector audio;
  bool _closed = false;
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await game.flushSaves();
    await settings.flushWrites();
    await audio.close();
    audio.dispose();
    game.dispose();
    settings.dispose();
  }

  /// Loads content (validating it in debug and profile builds), settings, and saved game.
  static Future<AppServices> load() async {
    final content = await ContentLoader.load(rootBundle.loadString);
    final prefs = await SharedPreferences.getInstance();
    return create(
      content: content,
      store: PrefsSettingsStore(prefs),
      gameStore: PrefsGameStore(prefs, content: content),
      audioBackend: LocalAudioBackend(),
    );
  }

  /// Builds services from already-loaded parts. Tests use this with fakes.
  static Future<AppServices> create({
    required GameContent content,
    required SettingsStore store,
    GameStore? gameStore,
    GuideProvider? guideProvider,
    AudioBackend? audioBackend,
    bool validate = !kReleaseMode,
  }) async {
    if (validate) {
      final report = ContentValidator(content).validate();
      if (!report.isValid) {
        throw ContentValidationException(report.describe());
      }
    }
    final savedState = await gameStore?.load();
    return AppServices(
      content: content,
      audioBackend: audioBackend,
      guide: GuideService(
        offline: OfflineGuide(content),
        provider: guideProvider,
      ),
      settings: await SettingsController.load(store),
      game: GameController(content, store: gameStore, initial: savedState),
    );
  }
}
