# Licenses and Assets

Every dependency and every file under `assets/` is listed here.

## Dependencies

| Package | Version | License | Source | Use |
|---------|---------|---------|--------|-----|
| flutter (SDK) | 3.47.7 | BSD-3-Clause | flutter.dev | Framework |
| cupertino_icons | 1.0.9 | MIT | pub.dev | Template default, currently unused |
| flutter_lints (dev) | 6.x | BSD-3-Clause | pub.dev | Lints |
| shared_preferences | 2.5.6 | BSD-3-Clause | pub.dev (flutter.dev publisher) | Stores display and accessibility settings |

No other direct packages are installed. Transitive platform packages for `shared_preferences` come from the same publisher under the same license.

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

Fonts: the app uses the device's serif font (Georgia where available, otherwise the platform serif). No font files are bundled or downloaded. Icons come from Flutter's Material Icons (Apache-2.0), which ship with the SDK. There is no audio yet.
