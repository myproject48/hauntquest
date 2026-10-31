# Licenses and Assets

Every dependency and every file under `assets/` is listed here.

## Dependencies

| Package | Version | License | Source | Use |
|---------|---------|---------|--------|-----|
| flutter (SDK) | 3.47.7 | BSD-3-Clause | flutter.dev | Framework |
| cupertino_icons | 1.0.9 | MIT | pub.dev | Template default, currently unused |
| flutter_lints (dev) | 6.x | BSD-3-Clause | pub.dev | Lints |
| shared_preferences | 2.5.6 | BSD-3-Clause | pub.dev (flutter.dev publisher) | Stores versioned progress and settings |

Audio playback uses `audioplayers` 6.8.1 (MIT; Blue Fire team, pub.dev). Platform implementations are resolved in `pubspec.lock`. See Flutter's bundled LicensePage for dependency licenses.

## Assets

| File | Origin | License |
|------|--------|---------|
| `assets/content/story.json` | Original text written for this project | Project license |
| `assets/content/rooms.json` | Original text written for this project | Project license |
| `assets/content/items.json` | Original text written for this project | Project license |
| `assets/content/puzzles.json` | Original text and puzzle data written for this project | Project license |
| `assets/content/choices.json` | Original text written for this project | Project license |

All characters (Tallow, Ottoline Vask, Wren Dabney, Edric Maul, the Echo), places, and story are original.

All visuals are original and drawn in code with `CustomPainter` in `lib/core/painting/`: the five room scenes, all 22 interactive objects, 10 item icons, 5 character portraits, the manor exterior, puzzle instruments, sigils, and three ending illustrations. No image files, stock art, or generated images are bundled.

Fonts: the app uses the device's serif font (Georgia where available, otherwise the platform serif). No font files are bundled or downloaded. Icons come from Flutter's Material Icons (Apache-2.0), which ship with the SDK. Original procedural audio is bundled; see below.


## Original audio

All 20 files under `assets/audio/*.wav` are original project sound design generated
by `tool/generate_audio.py`. No copyrighted recordings, music, stock packs, samples,
AI audio, or other third-party media are used. The generator uses sine partials,
damped envelopes and seeded noise; it is included for complete reproducibility.
These assets have the same ownership/license as the original project content.

- `ambient_hall`, `ambient_library`, `ambient_workshop`, `ambient_clocktower`, `ambient_vault`: periodic room soundscapes.
- `pickup`, `unlock`, `success`, `failure`, `footstep`, `discovery`, `chapter`, `interact`: interaction cues.
- `ending_release`, `ending_seal`, `ending_guardian`: distinct final reveals.
- `echo_220`, `echo_330`, `echo_440`, `echo_550`: optional audible puzzle tones, always paired with visual/written clues.

All files are 16 kHz, 16-bit, mono PCM WAV. The game does not fetch audio from the
network. Native player lifecycle behavior follows the
[audioplayers API](https://github.com/bluefireteam/audioplayers/blob/main/getting_started.md).

## Android launcher icon and launch screen

The launcher icon (`android/app/src/main/res/mipmap-*/ic_launcher.png`, `ic_launcher_foreground.png` and `mipmap-anydpi-v26/ic_launcher.xml`) is original artwork drawn in code: a moonlit manor tower in the game's palette. It is rendered by `tool/icon/generate_launcher_icon_test.dart` (run `flutter test tool/icon/generate_launcher_icon_test.dart` to regenerate it). The launch screen uses the `manor_midnight` color (`#050818`) from `res/values/colors.xml`. It replaces the Flutter template icon. No third-party artwork is used.
