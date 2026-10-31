import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../content/content_loader.dart';
import '../content/game_content.dart';
import '../content/validation/content_validator.dart';
import 'preview_controller.dart';
import 'settings_controller.dart';

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
    required this.preview,
  });

  final GameContent content;
  final SettingsController settings;
  final PreviewController preview;

  /// Loads content (validating it in debug and profile builds) and settings.
  static Future<AppServices> load() async {
    final content = await ContentLoader.load(rootBundle.loadString);
    return create(content: content, store: await PrefsSettingsStore.open());
  }

  /// Builds services from already-loaded parts. Tests use this with fakes.
  static Future<AppServices> create({
    required GameContent content,
    required SettingsStore store,
    bool validate = !kReleaseMode,
  }) async {
    if (validate) {
      final report = ContentValidator(content).validate();
      if (!report.isValid) {
        throw ContentValidationException(report.describe());
      }
    }
    return AppServices(
      content: content,
      settings: await SettingsController.load(store),
      preview: PreviewController(content),
    );
  }
}
