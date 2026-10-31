# HauntQuest AI

An original dark-fantasy mystery adventure game built with Flutter, created for
the Kiroween 2026 hackathon (Costume Contest category) using Kiro IDE.

All characters, environments, stories, and artwork are original. Every
illustration is drawn in code; no image files are bundled.

## Status

Playable preview. Done:

- Full story content (five rooms, ten items, nine puzzles, four dialogue
  choices, three endings) with automated validation.
- The game interface: splash, main menu, save slots, illustrated room
  exploration, inventory, puzzle screens, dialogue, journal and evidence board,
  settings, and endings.
- Puzzle answers are checked by real, tested evaluators.
- Display and accessibility settings apply immediately and are saved.

Not done yet: the game engine that applies rewards (items, open doors),
remembers dialogue choices, and saves progress; and audio. The app labels
these limits where they matter. Review mode (Settings, Review tools) reveals
the whole manor so every room and screen can be seen.

## The story

A letter from a frightened apprentice calls you to The Whispering Manor, where
the inventor Ottoline Vask vanished while chasing a phenomenon called the Echo.
Investigate, restore her Resonance Engine, and decide the Echo's fate. The
dependency map is in `docs/PROGRESSION_GRAPH.md`.

## Targets

- Android (primary; not yet run on a device)
- Flutter Web (release build verified)

## Structure

```
lib/
  app/            App root, services, settings, preview state
  core/
    design/       Tokens, theme extension, motion policy
    theme/        Colors and ThemeData
    painting/     All code-drawn art (rooms, objects, items, portraits, endings)
    widgets/      Shared components (buttons, panels, fog, grain, typewriter)
    navigation/   Page transition
  content/        Pure-Dart content models, loader, and validation
  domain/puzzles/ Pure puzzle evaluators
  features/       splash, menu, saves, intro, room, inventory, puzzle,
                  dialogue, journal, settings, ending, about
assets/content/   Story, rooms, items, puzzles, choices (JSON)
docs/             Progression graph, licenses
tool/             Content tooling
```

Regenerate the progression graph and validate content with
`dart run tool/generate_progression_graph.dart`.

## Run

```
flutter pub get
flutter run
flutter analyze
flutter test
```
