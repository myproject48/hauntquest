# Technology

## Stack (verified in the workspace)

- Flutter 3.47.7 (stable), Dart 3.13.5. `pubspec.yaml` SDK constraint: `^3.13.5`.
- Package name: `hauntquest` (imports use `package:hauntquest/...`). The app display title is "HauntQuest AI".
- Lints: `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`.
- Current dependencies: `flutter`, `cupertino_icons`, `shared_preferences` (settings); dev: `flutter_test`, `flutter_lints`.

## Platform Support

- Primary: Android (phones first, tablets must work).
- Secondary: Flutter Web (Chrome) where practical. Code must avoid `dart:io` in shared code paths; isolate platform-specific code behind interfaces.
- Android: debug build and an end-to-end integration test pass on an emulator (API 37). Not yet run on a physical phone.
- iOS, desktop folders exist from the template but are not targets.

## Dart and Flutter Conventions

- Prefer `const` constructors, `final` fields, and immutable models with `copyWith`, `==`, and `hashCode`.
- Use `package:` imports for cross-feature code; relative imports only inside the same feature or layer folder.
- Use `Color.withValues(alpha:)`, not the deprecated `withOpacity`. Use `MediaQuery.sizeOf` / `maybeOf` style accessors to limit rebuilds.
- Pattern matching, records, enums with members, and sealed classes are encouraged for conditions and effects.
- Doc comments (`///`) on public classes and non-obvious functions, in English.
- No `print`; use `debugPrint` or a small logger wrapper, and never log secrets.
- Avoid code generation (no build_runner, freezed, json_serializable). Write `fromJson`/`toJson` by hand.

## Dependency Management

- Add a package only when it removes real risk or large effort. Before adding: check pub.dev for compatibility with Dart 3.13 / Flutter 3.47, publisher verification, recent releases, and license.
- Pin to the tested version with a caret and record it in `docs/LICENSES_AND_ASSETS.md` (package, version, license, source).
- Do not add packages for navigation, state management, serialization, or fonts.
- Planned (not yet added), in order of need: `audioplayers` (audio, only if compatible, else a null audio service), `http` (optional AI only). `integration_test` comes from the SDK.
- Flag unusual or typosquat-like package names to the user before installing.

## State Management

- No third-party state library. Implemented: a pure-Dart `GameEngine` (no Flutter imports) applies named actions to an immutable `GameState` and returns the new state plus events. A `GameController` (ChangeNotifier / ValueNotifier) holds state and is exposed through `InheritedNotifier` / `InheritedWidget` (`AppScope`) so tests can inject fakes.
- Widgets read narrow slices with `ValueListenableBuilder` or selectors; they never mutate game rules.
- Settings live in a separate `SettingsController`, independent of game state.

## Navigation

- `Navigator` with simple named or direct routes for menu screens (title, intro, settings, about, ending).
- Rooms are not routes. `RoomScreen` renders the room from the current room id. Map, pause and examine are bottom sheets; inventory, journal, puzzle, dialogue and settings are pushed with `MistPageRoute` (`context.pushMist`).
- Back gesture: close the top overlay first, then show a pause prompt (use `PopScope`).

## Persistence

- Settings already persist through `SettingsStore` / `PrefsSettingsStore` (`lib/app/settings_controller.dart`); save failures are surfaced in Settings, not swallowed.
- Planned for game saves: `shared_preferences` storing JSON strings, with a checksum, a backup key, `schemaVersion`, and migration functions. Atomic-style write: copy valid primary to backup, then write the new primary.
- Game saves, settings, and meta progress (endings seen) use separate keys. Settings must survive new adventures and save deletion.
- Saves never contain personal data, device ids, or API keys.
- Not yet implemented.

## Content

- Story, rooms, items, puzzles, hints, and endings are JSON assets under `assets/content/` (planned), validated at load. Puzzle solutions live in data, not widget code.

## Testing Strategy

- Unit tests for the pure domain: engine actions, effect idempotency, each puzzle evaluator (correct / incorrect / partial), ending resolver (table-driven over all flag combinations), hint selection, serialization round trips, migrations.
- Content validation tests: assets parse, references resolve, five rooms, at least eight puzzles, three hint tiers per puzzle.
- Widget tests: key flows, semantics labels, 48 dp targets, text scale up to 200%, widths around 360 / 700 / 1100 dp, reduced motion.
- Integration tests: scripted playthroughs (slice first, then the three endings) offline.
- Tests mirror `lib/` under `test/`. Use fakes injected through `AppScope`, never real network, audio, or timers that leak.
- Existing (101 tests): content and validator tests in `test/content/`, puzzle evaluator tests in `test/domain/`, and UI tests in `test/ui/`. The UI tests cover every navigation path, full-motion rendering of every room, ending and puzzle, layouts at 320 to 1280 dp wide with 100% and 200% text, Flutter's tap-target and label guidelines, and palette contrast. `test/ui/ui_harness.dart` boots the real app with real content and an in-memory settings store.
- Widget tests render text with a placeholder font. To review visuals, load real fonts with `FontLoader` and capture the render view to PNG in a temporary test.
- Regenerate the dependency map after content changes: `dart run tool/generate_progression_graph.dart` (exits non-zero if validation fails).
- Content rule: any change to `assets/content/*.json` must keep `ContentValidator` at zero errors and zero warnings.

## Commands

```
flutter pub get
flutter analyze
flutter test
flutter run -d chrome        # web
flutter run                  # attached Android device/emulator
```

Do not run long-lived dev servers from agent tool calls; tell the user to run them.

## Secrets and Configuration

- No secrets in the repo. AI endpoint/key come from `--dart-define` or user entry in Settings, stored only in the settings store.

## Game Engine Rules

- All rules live in `GameEngine`; widgets call `GameController` actions and read state. Never change state from a widget.
- Rejected actions return the same state with `ActionRejected` (message + optional hint). Show both; never swallow.
- Effects are idempotent: items are never granted twice (`acquiredItemIds`), solved puzzles never re-reward, use rules apply once but may replay their text.
- On-device check: `flutter test integration_test -d <device>`.

## Agent Hooks

- v2 hooks live in `.kiro/hooks/*.json` (Kiro 1.4.62); details, verification and limits are in `docs/KIRO_WORKFLOW.md`.
- Hook scripts (`tool/hooks/`) must stay read-only: never edit project files, stage, commit, push or delete. This is what prevents hooks from re-triggering themselves.
- Create or change hooks with Kiro's `createHook` tool, not by hand. New hooks load at the next session start.
- Before committing outside the agent, include `#pre-commit-check`.

## Custom Agent, Skills, MCP, Powers

- `.kiro/agents/game-quality-agent.md` is a read-only reviewer (tools `read`, `shell`). Run it before a commit, demo or submission and act on its report. Details and limits are in `docs/KIRO_ADVANCED_FEATURES.md`.
- No MCP servers and no Kiro Powers are configured. Do not add either without a review. The `security-audit` skill is user-level (`~/.kiro/skills/`), not a Power.
