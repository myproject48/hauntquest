# Implementation Plan

Conventions:

- Each task is small and independently verifiable. "Verify" lines state how to confirm it is done.
- `_Depends on_` lists task numbers that must be complete first.
- Checkpoints require `flutter analyze` (no issues) and `flutter test` (all passing) before continuing.
- Phase A produces the **Vertical Slice** (Requirement 15). Phase B completes the full game. Phase C is polish and submission.
- Do not add a dependency without completing the license and compatibility check from design.md.

---

## Phase A: Vertical Slice

- [ ] 1. Domain models and state serialization
  - [ ] 1.1 Create `lib/domain/models/` with `PuzzleStatus`, `PuzzleProgress`, `StoryFlags`, `GameState`, `AppPhase`, and value equality
    - Immutable classes with `copyWith`, `==`, `hashCode`
    - _Requirements: 16.1, 16.2, 16.4_
  - [ ] 1.2 Implement `toJson`/`fromJson` using only primitive JSON types and `schemaVersion`
    - _Requirements: 8.4, 16.5_
  - [ ] 1.3 Write unit tests for round-trip equality and immutability
    - Verify: `flutter test test/domain/models` passes
    - _Requirements: 8.9, 16.4_
  - _Depends on: none_

- [x] 2. Content definitions and declarative rules
  - [x] 2.1 Create `lib/content/definitions/` (`RoomDef`, `ExitDef`, `HotspotDef`, `ItemDef`, `UseRule`, `PuzzleDef`, `ChoiceDef`, `EndingDef`, `EndingRule`, `ContextText`/`TextVariant`, `StoryDef`)
    - Done. Combine puzzles use `config.slots` instead of a separate `CombineRule` class.
    - _Requirements: 2.2, 3.2, 5.12_
  - [x] 2.2 Implement sealed `Condition` and `Effect` types with JSON parsing and a pure `Condition.evaluate(ProgressView)`
    - `ProgressView` is implemented by the validator's simulated state now and by `GameState` in task 1
    - Verified by `test/content/condition_test.dart`
    - _Requirements: 3.5, 7.3, 16.6_
  - _Depends on: 1_

- [ ] 3. Story content assets and content loading
  - [x] 3.1 Add `assets/content/*.json`: story, 5 rooms, 10 items, 9 puzzles with 3 hint tiers each, 4 choices, 3 endings, 5 voices
    - Done for the full game, not only the slice. Registered in `pubspec.yaml`. Original English text.
    - _Requirements: 2.1, 3.1, 5.12, 6.3, 15.1, 17.1_
  - [x] 3.2 Fail fast at startup if content is invalid
    - Done: `AppServices.create` validates at startup in debug/profile and the splash shows the error with a retry (tested).
    - Done: `ContentLoader` (injected reader) and `ContentValidator`. Remaining: call the validator at boot in debug builds and show a developer error screen (needs task 10 wiring)
    - _Requirements: 16.7_
  - [x] 3.3 Write content validation tests
    - Covers unique ids, references, reachable rooms, item requirements, reachable endings, missing and cyclic dependencies, hint tiers, clue text, text limits. See `test/content/`
    - _Requirements: 3.6, 6.3_
  - _Depends on: 2_

- [ ] 4. Game engine core: movement, examine, items
  - [ ] 4.1 Implement `GameEngine` with `newGame`, `moveToRoom`, `examineHotspot`, `inspectItem`, `useItemOnHotspot`, and idempotent `applyEffect`
    - Returns `EngineResult(state, events)`; no Flutter imports
    - _Requirements: 1.2, 2.3, 2.4, 2.5, 3.2, 3.3, 3.4, 3.5, 4.1, 4.5, 4.6, 4.9, 16.6_
  - [ ] 4.2 Define `GameEvent` hierarchy and `ActionRejected`
    - _Requirements: 16.6_
  - [ ] 4.3 Unit tests: examining twice grants an item once; locked exit blocks; use-rule success and failure; inventory order preserved
    - Verify: `flutter test test/domain/engine` passes
    - _Requirements: 2.4, 3.3, 4.7_
  - _Depends on: 2, 3_

- [ ] 5. Puzzle framework and slice evaluators (P1, P2, P3)
  - [ ] 5.1 Define `PuzzleEvaluator`, `PuzzleResult`, `Verdict`, and the registry keyed by `kind`
    - _Requirements: 5.5_
  - [x] 5.2 Implement `useItem`, `sequence`, and `cipher` evaluators
    - Pure evaluators for ALL seven kinds exist in `lib/domain/puzzles/puzzle_evaluator.dart` (tested). Remaining for task 5: the status machine in the engine (5.3).
    - _Requirements: 5.1, 5.5_
  - [ ] 5.3 Implement `GameEngine.submitPuzzle` with the status machine (`locked → available → inProgress → solved`), attempts counter, and idempotent `onSolved` effects
    - _Requirements: 5.2, 5.3, 5.4, 5.6, 5.7, 5.8, 5.10_
  - [ ] 5.4 Unit tests per puzzle (correct, incorrect, partial), solved never regresses, repeated submission does not duplicate items
    - Verify: `flutter test test/domain/puzzles` passes
    - _Requirements: 5.8_
  - _Depends on: 4_

- [ ] 6. Story choices and ending resolver
  - [ ] 6.1 Implement `ChoiceResolver` (preconditions, disabled reasons, one-time resolution) and engine action `resolveChoice`
    - _Requirements: 7.2, 7.3, 7.6_
  - [ ] 6.2 Implement `EndingResolver` with ordered rules from `endings.json`; engine action `checkEnding`
    - _Requirements: 7.7, 11.2, 11.8_
  - [ ] 6.3 Table-driven test over all 48 flag combinations (`truthFragments` 0–5 × `mercy` 0–3 × `acceptedBargain` 0–1) asserting exactly one ending
    - Verify: `flutter test test/domain/story` passes
    - _Requirements: 11.8_
  - _Depends on: 4_

- [ ] 7. Authored hint provider
  - [ ] 7.1 Implement target selection (priority puzzle in room → next objective → ending guidance) and tier escalation up to 3
    - Include the "missing item first" rule
    - _Requirements: 6.2, 6.3, 6.4, 6.7, 6.9_
  - [ ] 7.2 Engine action `requestHint` records `hintsUsed`
    - _Requirements: 6.6_
  - [ ] 7.3 Unit tests: determinism, escalation, item-first rule
    - Verify: `flutter test test/domain/hints` passes
    - _Requirements: 6.8_
  - _Depends on: 5_

- [ ] 8. Checkpoint A1: domain complete
  - Run `flutter analyze` and `flutter test`; fix all issues
  - Scripted domain-only playthrough test: new game → solve P1, P2, P3 → resolve choice → reach slice ending
  - _Depends on: 5, 6, 7_

- [ ] 9. Persistence
  - [ ] 9.1 Add `shared_preferences` (verified compatible; pinned) and record it in `docs/LICENSES_AND_ASSETS.md`
    - _Requirements: 17.2_
  - [ ] 9.2 Implement `SaveRepository` interface and `PrefsSaveRepository` with checksum, backup key, and atomic write protocol
    - _Requirements: 8.6, 8.7, 8.10_
  - [ ] 9.3 Implement `SaveMigrator` (empty chain for v1 plus a test migration fixture) and `GameStateValidator`
    - _Requirements: 8.5, 16.7_
  - [ ] 9.4 Implement `SettingsStore` and `MetaProgress` stored separately
    - _Requirements: 9.4, 11.5_
  - [ ] 9.5 Tests: round trip, corrupt primary falls back to backup, both corrupt returns `corrupt`, simulated interrupted write, settings survive save deletion
    - Verify: `flutter test test/data` passes
    - _Requirements: 8.3, 8.6, 8.7, 8.9, 9.4_
  - _Depends on: 1, 3_

- [ ] 10. GameController and app wiring
  - [ ] 10.1 Implement `GameController` (ValueNotifiers for state and phase, `dispatch`, events stream, phase transition table)
    - _Requirements: 16.2, 16.3_
  - [ ] 10.2 Add debounced autosave and `AppLifecycleListener` flush
    - _Requirements: 1.5, 8.1, 8.2, 13.5_
  - [ ] 10.3 Implement `AppScope` (InheritedWidget with `AppServices`) and `SettingsController`; wire into `HauntQuestApp`
    - Services injectable for tests
    - _Requirements: 9.3_
  - [ ] 10.4 Unit tests: illegal phase transitions rejected; autosave called after state-changing events; Continue restores state
    - Verify: `flutter test test/application` passes
    - _Requirements: 8.1, 8.3, 16.3_
  - _Depends on: 4, 5, 6, 9_

- [ ] 11. Title flow: new, continue, intro
  - [ ] 11.1 Update `HomeScreen` with New Adventure, Continue (visible only with a valid save), Settings, About
    - UI done (`MainMenuScreen`: Begin Quest, Continue, Settings, Credits). Remaining: show Continue only when a save exists (needs task 9).
    - _Requirements: 1.1_
  - [ ] 11.2 Overwrite confirmation dialog; cancel leaves the save unchanged
    - _Requirements: 1.3, 1.6_
  - [x] 11.3 `IntroScreen` with skip on single tap and reduced-motion-aware typewriter
    - Done: `IntroScreen` with Skip, tap-to-finish, reduced-motion aware `TypewriterText`.
    - _Requirements: 1.4_
  - [ ] 11.4 Widget tests for each flow
    - Verify: `flutter test test/features/home` passes
    - _Requirements: 1.1, 1.2, 1.3, 1.6_
  - _Depends on: 10_

- [ ] 12. Room scene and hotspot layer
  - [x] 12.1 Create `RoomScene` painters for the Moonlit Entrance Hall and Forgotten Library using the existing palette and `HauntedBackdrop` techniques
    - Done for all five rooms (`RoomArt`, `HotspotArt`), layered parallax.
    - Original, code-painted art only
    - _Requirements: 2.2, 17.1, 17.5_
  - [x] 12.2 Implement `HotspotLayer` from normalized areas with 48 dp minimum hit area, semantic labels, and optional highlight
    - Done in `RoomStage`: 48 dp minimum, semantic labels, kind badges (icon, not color only).
    - _Requirements: 3.1, 3.6, 3.8, 14.5_
  - [ ] 12.3 Implement `GameScreen` (Stack with scene, hotspot layer, HUD, overlay host) and room fade transition honoring reduced motion
    - UI done as `RoomScreen` + sheets, with fade transition. Remaining: drive it from `GameController` instead of `PreviewController`.
    - _Requirements: 2.3, 2.6, 13.4_
  - [x] 12.4 Text box overlay for descriptions and locked messages
    - Done: examine sheet; locked exits explain via snackbar.
    - _Requirements: 2.4, 3.5_
  - [ ] 12.5 Widget tests: tapping a hotspot dispatches examine; locked exit shows message; semantics labels present; layouts at 360, 700, 1100 dp widths
    - Layout, locked-exit and semantics tests done (`test/ui/`). Remaining: "dispatches examine" once the engine exists.
    - Verify: `flutter test test/features/game` passes
    - _Requirements: 3.2, 3.6, 14.1_
  - _Depends on: 10, 11_

- [ ] 13. Inventory and item inspect
  - [ ] 13.1 Inventory overlay reachable from the HUD in one tap, ordered by acquisition
    - _Requirements: 4.2, 4.7_
  - [x] 13.2 Item inspect view with `ItemIcon` painter and detail text; marks the item inspected
    - Done: inspect view with pedestal art and detail text. Remaining: mark inspected in game state.
    - _Requirements: 4.3, 4.4, 4.9_
  - [ ] 13.3 "Use on hotspot" selection mode
    - _Requirements: 3.4_
  - [ ] 13.4 Pickup toast
    - _Requirements: 4.1_
  - [ ] 13.5 Widget tests including 20 items at 200% text scale with no overflow
    - Verify: `flutter test test/features/inventory` passes
    - _Requirements: 4.8, 14.2_
  - _Depends on: 12_

- [ ] 14. Puzzle UI for slice puzzles
  - [ ] 14.1 `PuzzleHost` overlay: opens a puzzle view by `kind`, persists partial input in `PuzzleProgress.data`, closes without losing progress
    - _Requirements: 5.4, 5.10, 14.9_
  - [ ] 14.2 Tap-only widgets: `SequencePuzzleView` (P2), `CipherPuzzleView` (P3, letter-wheel or keyboard entry), and the `useItem` flow for P1
    - Views exist for all seven kinds (`puzzle_controls.dart`), tap-only. Remaining: persist partial input in `PuzzleProgress.data` (14.1).
    - Verdict feedback uses text and icon
    - _Requirements: 5.7, 14.4, 14.6_
  - [ ] 14.3 Widget tests for each view: correct, incorrect, partial, rotation keeps input
    - Verify: `flutter test test/features/puzzles` passes
    - _Requirements: 5.5, 14.9_
  - _Depends on: 12, 13_

- [ ] 15. Choice panel and hint sheet UI
  - [ ] 15.1 Choice panel with disabled options and reasons
    - _Requirements: 7.3_
  - [ ] 15.2 Hint button on every gameplay screen opening a hint sheet that shows tiers progressively
    - _Requirements: 6.1, 6.4, 6.5_
  - [ ] 15.3 Widget tests for both
    - Verify: `flutter test test/features/hints test/features/choices` passes
    - _Requirements: 6.1, 7.3_
  - _Depends on: 12, 7_

- [ ] 16. Settings screen and audio service
  - [ ] 16.1 `AppSettings` model and Settings screen: music/SFX volume, mute, reduced motion, high contrast, text size, highlight interactables, spaced text, tutorial replay, delete saves with confirmation
    - Done: text size, reduced motion, high contrast, spaced text, highlight interactables, list mode; persisted. Remaining: audio controls (no audio yet), tutorial replay, delete saves.
    - Changes apply immediately and persist
    - _Requirements: 8.11, 9.1, 9.2, 9.3, 14.8_
  - [x] 16.2 Apply text scale, high-contrast theme, and `MotionPolicy` at app root; default reduced motion from OS
    - Done: applied at app root; OS reduced-motion honored through `MotionPolicy`.
    - _Requirements: 9.5, 9.6, 14.3_
  - [ ] 16.3 `AudioService` interface, `NullAudioService`, and `audioplayers` implementation (after license/compat check; otherwise stay on Null and record the decision)
    - Handles init failure and missing assets without crashing; pauses on background
    - Original or CC0 audio only, recorded in `docs/LICENSES_AND_ASSETS.md`
    - _Requirements: 9.7, 9.8, 17.2, 17.5_
  - [ ] 16.4 Tests: settings persist independent of saves, apply immediately; reduced motion disables the backdrop animation; audio failure does not throw
    - Verify: `flutter test test/features/settings test/services/audio` passes
    - _Requirements: 9.3, 9.4, 9.6, 9.7_
  - _Depends on: 10, 12_

- [ ] 17. Ending screen (slice ending)
  - [ ] 17.0 Decide the slice scope. The authored story is a single chain through all five rooms, so a two-room slice cannot reach a real ending. Either (a) ship all five rooms with simple scenes in the slice, or (b) add an authored early-exit ending after P3. Record the decision here before building the ending screen
  - [ ] 17.1 `EndingScreen` with epilogue, summary (puzzles solved, hints used, choices), and return to title / new adventure
    - Screen done (`EndingScreen`, art and epilogue). Remaining: summary of the run and reaching it from the final choice.
    - _Requirements: 11.3, 11.4, 11.6_
  - [ ] 17.2 Record `endingsSeen` in meta store
    - _Requirements: 11.5_
  - [ ] 17.3 Widget test for ending summary
    - Verify: `flutter test test/features/ending` passes
    - _Requirements: 11.4_
  - _Depends on: 10, 6_

- [ ] 18. Checkpoint A2: slice integration
  - [ ] 18.1 Integration test: title → new → solve P1, P2, P3 → choice → ending, offline, then Continue after restart restores state
    - _Requirements: 10.2, 15.2, 8.3_
  - [ ] 18.2 Offline guarantee test with a throwing network client (zero network calls)
    - _Requirements: 10.3, 10.6_
  - [ ] 18.3 Run `flutter analyze` and `flutter test`; fix all issues
    - _Requirements: 15.4_
  - _Depends on: 14, 15, 16, 17_

- [ ] 19. Accessibility pass on the slice
  - [ ] 19.1 Contrast checker utility and test for palette (4.5:1 default, 7:1 high contrast)
    - _Requirements: 14.3_
  - [x] 19.2 Accessible "list view" of hotspots and exits for screen readers
    - Done: "List objects as buttons" setting, auto-on when a screen reader is detected.
    - _Requirements: 14.7_
  - [ ] 19.3 Skippable control tutorial overlay
    - _Requirements: 14.8_
  - [ ] 19.4 Back-gesture handling (`PopScope`)
    - _Requirements: 14.11_
  - [x] 19.5 Widget tests at 200% text scale across three widths
    - Done: 320, 430, 820, 1280 dp at 100% and 200% text (`test/ui/responsive_test.dart`).
    - Verify: `flutter test test/accessibility` passes
    - _Requirements: 14.1, 14.2_
  - _Depends on: 18_

- [ ] 20. **Milestone: Demonstration-ready vertical slice**
  - [ ] 20.1 Write `docs/DEMO_SCRIPT.md` happy-path walkthrough (2–3 minutes)
    - _Requirements: 15.6_
  - [ ] 20.2 Build and run on an Android device or emulator (and Chrome if practical); confirm cold start under 3 s, no crashes, airplane-mode play
    - _Requirements: 13.1, 15.2_
  - [x] 20.3 Create `docs/LICENSES_AND_ASSETS.md` entries and an About screen with credits and license page
    - Done: About screen with credits and license page; licenses doc updated.
    - _Requirements: 17.2, 17.3, 17.4_
  - [ ] 20.4 Final `flutter analyze` and `flutter test` pass
    - _Requirements: 15.4_
  - Exit criteria: the slice is playable start to ending offline with save/resume, hints, settings, and accessibility options.
  - _Depends on: 18, 19_

---

## Phase B: Full Game

- [ ] 21. Remaining content and rooms
  - [x] 21.1 Alchemist's Workshop, Clocktower Chamber, and The Echo Vault definitions with ≥ 3 hotspots each, exits, and items
    - Done early, in the content foundation step
    - _Requirements: 2.1, 2.7, 2.8, 3.1_
  - [x] 21.2 P4–P9 definitions, 3 hint tiers each, and the remaining Choice_Events
    - Done early, in the content foundation step
    - _Requirements: 5.1, 5.9, 6.3, 7.1_
  - [x] 21.3 The real three endings (A Quiet Dawn, The Homecoming, The Keeper's Chair)
    - Done early. Remaining for the slice: see task 17.0
    - _Requirements: 11.1, 11.3, 15.5_
  - [x] 21.4 Content validation tests (5 rooms, 9 puzzles, connectivity, dependency chain)
    - Verified: `flutter test test/content` passes
    - _Requirements: 2.1, 2.8, 5.1_
  - _Depends on: 20_

- [ ] 22. Remaining puzzle evaluators
  - [ ] 22.1 Implement `combine` (P4), `dial` (P5), `clock` (P7), and `gears` (P8); reuse `sequence` for P9 and `useItem` for P6
    - _Requirements: 5.1, 5.9_
  - [ ] 22.2 Unit tests for each (correct, incorrect, partial)
    - _Requirements: 5.5_
  - _Depends on: 21_

- [ ] 23. Remaining puzzle views
  - [x] 23.1 `CombinePuzzleView`, `DialPuzzleView`, `ClockPuzzleView`, `GearsPuzzleView` with stepper (tap-only) controls
    - Done early.
    - _Requirements: 14.6_
  - [ ] 23.2 Widget tests for each including rotation retention
    - Verify: `flutter test test/features/puzzles` passes
    - _Requirements: 14.9_
  - _Depends on: 22_

- [ ] 24. Remaining room scenes
  - [x] 24.1 Painters for the Alchemist's Workshop, Clocktower Chamber, and The Echo Vault with distinct mood, plus ambient cue ids
    - Done early. Ambient cue ids are in content; no audio yet.
    - _Requirements: 2.2, 17.5_
  - [x] 24.2 Map overlay listing visited rooms and current location
    - Done early (map sheet).
    - _Requirements: 2.7_
  - [ ] 24.3 Widget tests for map and room rendering
    - _Requirements: 2.6, 2.7_
  - _Depends on: 21_

- [ ] 25. Full story and endings
  - [ ] 25.1 Flag-driven `TextVariant` usage in descriptions and dialogue
    - _Requirements: 7.5_
  - [ ] 25.2 Three distinct ending screens (art, epilogue, music cue)
    - Art and epilogue for all three done. Remaining: music cues (no audio).
    - _Requirements: 11.3_
  - [ ] 25.3 Three scripted playthrough tests (one per ending) using documented action sequences
    - Verify: `flutter test test/integration/endings_test.dart` passes
    - _Requirements: 11.2, 11.7, 5.11_
  - _Depends on: 22, 23, 24_

- [ ] 26. Manual save slots
  - [ ] 26.1 Three manual slots plus autosave in `SaveRepository`; slot UI in pause menu and title screen
    - _Requirements: 8.8_
  - [ ] 26.2 Tests for slot isolation and delete
    - _Requirements: 8.11_
  - _Depends on: 25_

- [ ] 27. Checkpoint B1: full game complete
  - Run `flutter analyze` and `flutter test`; fix all issues
  - Property-style test with seeded random actions confirms invariants (no duplicate inventory, solved never regresses, state always validates)
  - _Depends on: 25, 26_

- [ ] 28. Optional AI layer
  - [ ] 28.1 `AiService` interface, `NullAiService` default, `AiConfig` (build-time defines and user-entered values stored only in settings)
    - _Requirements: 12.1, 12.2, 12.9, 12.10_
  - [ ] 28.2 `AiOutputValidator` (non-empty, ≤ 400 chars, no URLs/markup, no solution leakage below tier 3)
    - _Requirements: 12.6_
  - [ ] 28.3 `HintCoordinator`: authored hint first, optional AI swap within 4 s, silent fallback on every failure mode
    - _Requirements: 12.3, 12.4, 12.5, 12.12_
  - [ ] 28.4 Consent notice and Settings AI toggle (hidden when unconfigured)
    - _Requirements: 9.9, 12.7, 12.8_
  - [ ] 28.5 Deterministic flavor-line fallback table; optional flavor display that never replaces authored text
    - _Requirements: 12.11, 12.12_
  - [ ] 28.6 Add `http` only now (after license/compat check) and implement `HttpAiService` with timeout; no credentials in repo
    - _Requirements: 12.9, 17.2_
  - [ ] 28.7 Tests with a fake `AiService`: success, timeout, failure, empty, URL, over-length, spoiler; asserts no `GameState` mutation and zero network when unconfigured
    - Verify: `flutter test test/services/ai` passes
    - _Requirements: 12.3, 12.5, 12.6, 10.3_
  - _Depends on: 27_

- [ ] 29. Checkpoint B2: full offline verification
  - Offline integration run for all three endings with a throwing network client
  - `flutter analyze` and `flutter test`
  - _Requirements: 10.2, 10.6, 11.7_
  - _Depends on: 28_

---

## Phase C: Polish and Submission

- [ ] 30. Performance pass
  - [ ] 30.1 Profile-mode scripted run, collect frame timings, fix hot spots (repaint boundaries, painter caching, stop animation when backgrounded)
    - _Requirements: 13.2, 13.8_
  - [ ] 30.2 Measure save duration and state size
    - _Requirements: 13.5, 13.6_
  - [ ] 30.3 Release build size check
    - _Requirements: 13.7_
  - _Depends on: 29_

- [ ] 31. Accessibility and device matrix pass
  - [ ] 31.1 TalkBack walkthrough of the full game; fix labels and order
    - _Requirements: 14.7_
  - [ ] 31.2 Verify no content flashes faster than 3 Hz; verify high contrast on every screen
    - _Requirements: 14.3, 14.10_
  - [ ] 31.3 Test on small phone, large phone, tablet, and Chrome
    - _Requirements: 14.1_
  - _Depends on: 29_

- [ ] 32. Licensing and submission materials
  - [ ] 32.1 Script/test verifying every dependency and asset file is in `docs/LICENSES_AND_ASSETS.md`
    - _Requirements: 17.2_
  - [ ] 32.2 Final README (what it is, how to run, features, how Kiro was used: spec, steering, hooks), demo script update, ensure `.kiro/` is tracked
    - _Requirements: 17.6_
  - [ ] 32.3 Build release APK and, if practical, Flutter Web build
    - _Requirements: 13.7_
  - _Depends on: 30, 31_

- [ ] 33. **Milestone: Final release checkpoint**
  - `flutter analyze`: no issues; `flutter test` and integration tests: all passing
  - All 17 requirements' acceptance tests in the matrix pass or have recorded manual verification
  - Airplane-mode playthrough of all three endings on a device
  - _Depends on: 32_

---

## Dependency Overview

```
1 → 2 → 3 → 4 → 5 → 7 ─┐
              4 → 6 ────┤
1,3 → 9 ────────────────┼→ 8 (checkpoint)
4,5,6,9 → 10 → 11 → 12 → 13 → 14
                   12,7 → 15
                   10,12 → 16
                   10,6 → 17
14,15,16,17 → 18 → 19 → 20 (DEMO-READY SLICE)
20 → 21 → 22 → 23 ┐
          21 → 24 ┼→ 25 → 26 → 27 → 28 → 29 → 30,31 → 32 → 33
```

## Suggested Order of Execution

1, 2, 3, 4, 5, 6, 7, **8**, 9, 10, 11, 12, 13, 14, 15, 16, 17, **18**, 19, **20 (demo-ready)**, 21, 22, 23, 24, 25, 26, **27**, 28, **29**, 30, 31, 32, **33**.
