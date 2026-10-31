import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'persistence/atomic_preferences.dart';

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
    this.masterVolume = .7,
    this.ambientVolume = .35,
    this.effectsVolume = .65,
    this.muted = false,
  }) : assert(masterVolume >= 0 && masterVolume <= 1),
       assert(ambientVolume >= 0 && ambientVolume <= 1),
       assert(effectsVolume >= 0 && effectsVolume <= 1);

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
  final double masterVolume, ambientVolume, effectsVolume;
  final bool muted;

  AppSettings copyWith({
    double? textScale,
    bool? reducedMotion,
    bool? highContrast,
    bool? spacedText,
    bool? highlightInteractables,
    bool? roomListMode,
    double? masterVolume,
    double? ambientVolume,
    double? effectsVolume,
    bool? muted,
  }) => AppSettings(
    textScale: textScale ?? this.textScale,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    highContrast: highContrast ?? this.highContrast,
    spacedText: spacedText ?? this.spacedText,
    highlightInteractables:
        highlightInteractables ?? this.highlightInteractables,
    roomListMode: roomListMode ?? this.roomListMode,
    masterVolume: masterVolume ?? this.masterVolume,
    ambientVolume: ambientVolume ?? this.ambientVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
    muted: muted ?? this.muted,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'textScale': textScale,
    'reducedMotion': reducedMotion,
    'highContrast': highContrast,
    'spacedText': spacedText,
    'highlightInteractables': highlightInteractables,
    'roomListMode': roomListMode,
    'masterVolume': masterVolume,
    'ambientVolume': ambientVolume,
    'effectsVolume': effectsVolume,
    'muted': muted,
  };
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    double volume(String key, double fallback) {
      final v = json[key];
      return v is num && v.isFinite ? v.toDouble().clamp(0, 1) : fallback;
    }

    return AppSettings(
      textScale: textScales.contains(json['textScale'])
          ? (json['textScale'] as num).toDouble()
          : d.textScale,
      reducedMotion: flag('reducedMotion', d.reducedMotion),
      highContrast: flag('highContrast', d.highContrast),
      spacedText: flag('spacedText', d.spacedText),
      highlightInteractables: flag(
        'highlightInteractables',
        d.highlightInteractables,
      ),
      roomListMode: flag('roomListMode', d.roomListMode),
      muted: flag('muted', d.muted),
      masterVolume: volume('masterVolume', d.masterVolume),
      ambientVolume: volume('ambientVolume', d.ambientVolume),
      effectsVolume: volume('effectsVolume', d.effectsVolume),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.textScale == textScale &&
      other.reducedMotion == reducedMotion &&
      other.highContrast == highContrast &&
      other.spacedText == spacedText &&
      other.highlightInteractables == highlightInteractables &&
      other.roomListMode == roomListMode &&
      other.masterVolume == masterVolume &&
      other.ambientVolume == ambientVolume &&
      other.effectsVolume == effectsVolume &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(
    textScale,
    reducedMotion,
    highContrast,
    spacedText,
    highlightInteractables,
    roomListMode,
    masterVolume,
    ambientVolume,
    effectsVolume,
    muted,
  );
}

/// Where settings are stored.
abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Stores settings with `shared_preferences`.
class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs)
    : _atomic = AtomicPreferences(
        SharedPreferenceStorage(_prefs),
        'settings.v2',
      );
  final AtomicPreferences _atomic;

  final SharedPreferences _prefs;

  static const _prefix = 'settings.v1.';

  static Future<PrefsSettingsStore> open() async =>
      PrefsSettingsStore(await SharedPreferences.getInstance());

  @override
  Future<AppSettings> load() async {
    for (final slot in _atomic.candidates()) {
      try {
        final raw = jsonDecode(slot.payload);
        if (raw is Map<String, dynamic> && raw['schemaVersion'] == 2) {
          _atomic.select(slot);
          return AppSettings.fromJson(raw);
        }
      } catch (_) {
        /* Recover backup or legacy defaults. */
      }
    }
    return AppSettings.fromJson({
      'textScale': _prefs.get('${_prefix}textScale'),
      'reducedMotion': _prefs.get('${_prefix}reducedMotion'),
      'highContrast': _prefs.get('${_prefix}highContrast'),
      'spacedText': _prefs.get('${_prefix}spacedText'),
      'highlightInteractables': _prefs.get('${_prefix}highlight'),
      'roomListMode': _prefs.get('${_prefix}roomList'),
    });
  }

  @override
  Future<void> save(AppSettings s) => _atomic.commit(jsonEncode(s.toJson()));
}

/// Holds the current settings, applies changes immediately, and persists them.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store, [AppSettings initial = const AppSettings()])
    : _settings = initial;

  final SettingsStore _store;
  AppSettings _settings;
  Object? _lastSaveError;
  Future<void> _writes = Future.value();
  bool _disposed = false;

  AppSettings get settings => _settings;

  /// Set when the last attempt to save failed, so the UI can say so.
  Object? get lastSaveError => _lastSaveError;

  static Future<SettingsController> load(SettingsStore store) async =>
      SettingsController(store, await store.load());

  Future<void> update(AppSettings next, {bool persist = true}) async {
    if (next == _settings) return;
    _settings = next;
    notifyListeners();
    if (!persist) return;
    await saveCurrent();
  }

  Future<void> flushWrites() => _writes.catchError((Object _) {});
  Future<void> saveCurrent() async {
    final next = _settings;
    _writes = _writes.catchError((Object _) {}).then((_) => _store.save(next));
    try {
      await _writes;
      _lastSaveError = null;
    } catch (error, stack) {
      _lastSaveError = error;
      debugPrint('Could not save settings: $error\n$stack');
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
