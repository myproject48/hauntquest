import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player-facing display and accessibility settings.
@immutable
class AppSettings {
  const AppSettings({
    this.textScale = 1.0,
    this.reducedMotion = false,
    this.highContrast = false,
    this.spacedText = false,
    this.highlightInteractables = true,
    this.roomListMode = false,
  });

  /// Allowed text sizes, as multipliers.
  static const List<double> textScales = [1.0, 1.25, 1.5, 2.0];

  final double textScale;

  /// Reduce continuous and large animation. The device accessibility setting
  /// is honored in addition to this.
  final bool reducedMotion;
  final bool highContrast;

  /// Extra letter and line spacing.
  final bool spacedText;

  /// Show markers on tappable objects in rooms.
  final bool highlightInteractables;

  /// Also list a room's objects and exits as buttons (helpful with screen
  /// readers and switch access).
  final bool roomListMode;

  AppSettings copyWith({
    double? textScale,
    bool? reducedMotion,
    bool? highContrast,
    bool? spacedText,
    bool? highlightInteractables,
    bool? roomListMode,
  }) => AppSettings(
    textScale: textScale ?? this.textScale,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    highContrast: highContrast ?? this.highContrast,
    spacedText: spacedText ?? this.spacedText,
    highlightInteractables:
        highlightInteractables ?? this.highlightInteractables,
    roomListMode: roomListMode ?? this.roomListMode,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.textScale == textScale &&
      other.reducedMotion == reducedMotion &&
      other.highContrast == highContrast &&
      other.spacedText == spacedText &&
      other.highlightInteractables == highlightInteractables &&
      other.roomListMode == roomListMode;

  @override
  int get hashCode => Object.hash(
    textScale,
    reducedMotion,
    highContrast,
    spacedText,
    highlightInteractables,
    roomListMode,
  );
}

/// Where settings are stored.
abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Stores settings with `shared_preferences`.
class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'settings.v1.';

  static Future<PrefsSettingsStore> open() async =>
      PrefsSettingsStore(await SharedPreferences.getInstance());

  @override
  Future<AppSettings> load() async {
    const d = AppSettings();
    final stored = _prefs.getDouble('${_prefix}textScale');
    return AppSettings(
      textScale: AppSettings.textScales.contains(stored)
          ? stored!
          : d.textScale,
      reducedMotion:
          _prefs.getBool('${_prefix}reducedMotion') ?? d.reducedMotion,
      highContrast: _prefs.getBool('${_prefix}highContrast') ?? d.highContrast,
      spacedText: _prefs.getBool('${_prefix}spacedText') ?? d.spacedText,
      highlightInteractables:
          _prefs.getBool('${_prefix}highlight') ?? d.highlightInteractables,
      roomListMode: _prefs.getBool('${_prefix}roomList') ?? d.roomListMode,
    );
  }

  @override
  Future<void> save(AppSettings s) async {
    await Future.wait([
      _prefs.setDouble('${_prefix}textScale', s.textScale),
      _prefs.setBool('${_prefix}reducedMotion', s.reducedMotion),
      _prefs.setBool('${_prefix}highContrast', s.highContrast),
      _prefs.setBool('${_prefix}spacedText', s.spacedText),
      _prefs.setBool('${_prefix}highlight', s.highlightInteractables),
      _prefs.setBool('${_prefix}roomList', s.roomListMode),
    ]);
  }
}

/// Holds the current settings, applies changes immediately, and persists them.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store, [AppSettings initial = const AppSettings()])
    : _settings = initial;

  final SettingsStore _store;
  AppSettings _settings;
  Object? _lastSaveError;

  AppSettings get settings => _settings;

  /// Set when the last attempt to save failed, so the UI can say so.
  Object? get lastSaveError => _lastSaveError;

  static Future<SettingsController> load(SettingsStore store) async =>
      SettingsController(store, await store.load());

  Future<void> update(AppSettings next) async {
    if (next == _settings) return;
    _settings = next;
    notifyListeners();
    try {
      await _store.save(next);
      _lastSaveError = null;
    } catch (error, stack) {
      _lastSaveError = error;
      debugPrint('Could not save settings: $error\n$stack');
      notifyListeners();
    }
  }
}
