> Release note — November 1, 2026: this document retains the original planning
> history. The implemented game now has 16 puzzles, Release/Seal/Guardian endings,
> schema-v2 autosave, original audio and an offline Whispering Guide. Historical
> unchecked tasks/earlier ending names are not the current feature inventory.
> See [README](../../../README.md) and
> [release validation](../../../docs/RELEASE_VALIDATION.md) for verified scope and limits.

# Requirements Document

## Introduction

HauntQuest AI is an original, atmospheric mystery adventure for Android (primary) and Flutter Web (where practical). A letter from a frightened apprentice, Wren Dabney, calls the player to **The Whispering Manor** (Vask Manor), where the inventor Ottoline Vask vanished while investigating a phenomenon called **the Echo**. The player must learn what happened, restore the Resonance Engine, and decide the Echo's fate. Across five distinct rooms the player interacts with objects, collects and inspects clues, solves nine interconnected puzzles, makes narrative decisions, and reaches one of three endings.

The game is **fully playable offline** with authored, deterministic content. An **optional AI layer** can rephrase hints and add narrative flavor when configured, but the game never depends on it and always has a deterministic fallback.

All player-facing text, code documentation, and submission materials are in English. All characters, environments, stories, audio, and artwork are original.

### Scope Decisions

- No custom backend. Persistence is local to the device.
- Core gameplay (domain logic, content, persistence, UI) is separate from the optional AI service. The core compiles and runs with the AI code path unreachable.
- Minimum deliverable is a **vertical slice** (Requirement 15). Full game is the target after the slice is demonstrable.

### Glossary

- **Game_Engine**: Pure-Dart domain logic that holds and mutates game state with no Flutter or I/O dependency.
- **Game_State**: The complete serializable snapshot of a run (see Requirement 16).
- **Room**: A single explorable scene containing hotspots (interactable objects) and exits.
- **Hotspot**: An interactable object inside a Room.
- **Item**: An inventory object, either a physical object or a clue (note, page, symbol).
- **Puzzle**: A self-contained challenge with a state, an evaluator, and tiered hints.
- **Story_Flag**: A named boolean or integer in Game_State used for branching.
- **Choice_Event**: A narrative decision with options that apply Story_Flag effects.
- **Ending_Resolver**: Deterministic function mapping Story_Flags to one of three endings.
- **Hint_Provider**: Component that returns a hint for the current context. Two implementations exist: Authored (default, offline) and AI_Enhanced (optional).
- **AI_Service**: Optional component that may rewrite hint or narration text; never alters Game_State.
- **Save_Repository**: Component that persists and loads Game_State.
- **Settings_Store**: Component that persists user settings separately from Game_State.

### The Five Rooms

The authored content lives in `assets/content/*.json` and is validated by `ContentValidator` (see `test/content/`). A generated dependency map is in `docs/PROGRESSION_GRAPH.md`.

1. **Moonlit Entrance Hall** (`moonlit_hall`) – candelabra, dormant caretaker Tallow, portrait of Ottoline.
2. **Forgotten Library** (`forgotten_library`) – dark until Tallow's lantern is found; desk, cipher shelf, hearth, blotter, Maul's ledger.
3. **Alchemist's Workshop** (`alchemist_workshop`) – corroded cabinet, phonograph, resonance tuner, speaking horn.
4. **Clocktower Chamber** (`clocktower_chamber`) – stopped clock, drive gears, keeper's logbook, speaking tube.
5. **The Echo Vault** (`echo_vault`) – the Resonance Engine, the Echo, and the final choice.

### The Nine Puzzles

| ID | Room | Puzzle | Type |
|----|------|--------|------|
| P1 | Entrance Hall | Candle Moons | Ordered sequence (order from Wren's letter) |
| P2 | Entrance Hall | Wake the Caretaker | Use item (brass key on Tallow) |
| P3 | Library | The Whispering Shelf | Caesar cipher entry (shift from Ottoline's journal) |
| P4 | Library | Torn Recipe | Combine two torn pages into a solvent |
| P5 | Workshop | Resonance Tuner | Dial to a number heard on the wax cylinder |
| P6 | Workshop | Corroded Cabinet | Use item (solvent on cabinet) |
| P7 | Clocktower | Stopped Hands | Set clock to 11:40 from Wren's letter |
| P8 | Clocktower | Drive Gears | Seat the spare cog, set gears from the journal |
| P9 | Echo Vault | The Resonance Engine | Ordered pillars, order spread across three clues |

### Supporting Voices

Tallow (clockwork caretaker), Ottoline Vask (inventor, via recordings and journal), Wren Dabney (apprentice, via letter), Edric Maul (investor who sabotaged the engine, via speaking tube and ledger), and the Echo.

### The Three Endings

- **A Quiet Dawn** – the player releases the Echo. Always available.
- **The Homecoming** – the player calls Ottoline home. Needs at least 4 truth fragments, mercy of at least 2, and no bargain with Maul.
- **The Keeper's Chair** – the player claims the Echo. Needs the bargain accepted from Maul.

---

## Requirements

### Requirement 1: Start a New Adventure

**User Story:** As a player, I want to start a new adventure, so that I can begin The Whispering Manor from the beginning.

#### Acceptance Criteria

1. WHEN the app finishes launching THEN the system SHALL display a title screen with "New Adventure", "Continue" (only if a save exists), "Settings", and "About" options.
2. WHEN the player selects "New Adventure" and no save exists THEN the system SHALL create a fresh Game_State in the Entrance Hall with an empty inventory, all puzzles in their initial states, and all Story_Flags at default values.
3. WHEN the player selects "New Adventure" and a save exists THEN the system SHALL ask for confirmation before overwriting that save.
4. WHEN a new adventure starts THEN the system SHALL show a short introduction that can be skipped with a single tap.
5. WHEN a new adventure starts THEN the system SHALL write an initial autosave within 1 second.
6. IF the player cancels the overwrite confirmation THEN the system SHALL leave the existing save unchanged.

### Requirement 2: Explore Five Distinct Rooms

**User Story:** As a player, I want to explore five distinct rooms, so that the manor feels like a real place with its own atmosphere and secrets.

#### Acceptance Criteria

1. The system SHALL provide exactly five Rooms: Moonlit Entrance Hall, Forgotten Library, Alchemist's Workshop, Clocktower Chamber, and The Echo Vault.
2. Each Room SHALL have a unique name, description, visual scene, ambient audio identifier, and color mood.
3. WHEN the player selects an unlocked exit THEN the system SHALL transition to the destination Room with a fade or equivalent animation and update `currentRoomId` in Game_State.
4. IF an exit is locked THEN the system SHALL keep the player in the current Room and show a message explaining that the way is blocked, without revealing the solution.
5. WHEN a locked exit's unlock condition becomes true THEN the system SHALL mark the exit as open and persist the change.
6. WHEN the player re-enters a previously visited Room THEN the system SHALL render it reflecting all earlier state changes (solved puzzles, taken items, changed hotspots).
7. The system SHALL provide a map or room list that shows visited Rooms and the player's current Room.
8. The Room graph SHALL be connected such that every Room is reachable once all required puzzles are solved.

### Requirement 3: Interact with Environmental Objects

**User Story:** As a player, I want to interact with environmental objects, so that I can discover clues and progress the story.

#### Acceptance Criteria

1. Each Room SHALL contain at least three Hotspots.
2. WHEN the player taps a Hotspot THEN the system SHALL perform that Hotspot's authored action: show a description, give an Item, start a Puzzle, trigger a Choice_Event, or change state.
3. WHEN the player taps a Hotspot they have already examined THEN the system SHALL show its post-interaction description and SHALL NOT grant an Item twice.
4. WHEN an Item is selected from the inventory and applied to a Hotspot THEN the system SHALL evaluate the authored use-rule and either apply its effects or show a deterministic "that does not work" message.
5. IF a Hotspot has an unmet precondition THEN the system SHALL show its authored locked-state text and SHALL NOT change Game_State.
6. Every Hotspot SHALL be reachable by touch with a minimum 48×48 dp target and SHALL have a semantic label.
7. WHEN a Hotspot interaction changes state THEN the system SHALL give visual and optional audio feedback within 150 ms.
8. WHEN the player enables "Highlight interactables" in settings THEN the system SHALL show a visible indicator on all Hotspots in the current Room.

### Requirement 4: Collect and Inspect Inventory Items

**User Story:** As a player, I want to collect and inspect inventory items, so that I can use them and understand clues.

#### Acceptance Criteria

1. WHEN the player obtains an Item THEN the system SHALL add it to the inventory exactly once and show a pickup notification.
2. The inventory SHALL be accessible from every gameplay screen in no more than one tap.
3. WHEN the player selects an Item THEN the system SHALL open an inspect view showing its name, an illustration, and an authored description.
4. WHERE an Item is inspectable in detail (for example a note or torn page) THEN the system SHALL display the full clue text or drawing.
5. WHEN a combination rule consumes multiple Items to create a new Item THEN the system SHALL remove the consumed Items, add the result, and persist the change.
6. IF a puzzle consumes an Item THEN the system SHALL remove it from the inventory once and record the consumption in Game_State.
7. The inventory SHALL display Items in acquisition order and SHALL preserve that order across save and load.
8. The inventory SHALL support at least 20 Items without layout overflow at 200% text scale.
9. WHEN the player has seen a clue Item THEN the system SHALL record it as `inspected` in Game_State.

### Requirement 5: Solve at Least Eight Unique Puzzles

**User Story:** As a player, I want to solve at least eight unique puzzles, so that I feel I am investigating a real mystery.

#### Acceptance Criteria

1. The full game SHALL contain nine Puzzles (P1–P9), each with a unique mechanic or unique solution data.
2. Each Puzzle SHALL have exactly one of the states: `locked`, `available`, `inProgress`, `solved`.
3. WHEN a Puzzle's prerequisites are met THEN the system SHALL transition it from `locked` to `available`.
4. WHEN the player first interacts with an `available` Puzzle THEN the system SHALL transition it to `inProgress`.
5. WHEN the player submits an input THEN the Puzzle evaluator SHALL return `correct`, `incorrect`, or `partial` using only the input and Game_State (pure and deterministic).
6. WHEN the evaluator returns `correct` THEN the system SHALL transition the Puzzle to `solved`, apply its effects (grant Item, open exit, set Story_Flag), and persist.
7. WHEN the evaluator returns `incorrect` THEN the system SHALL increment that Puzzle's `attempts` counter and show non-punishing feedback, and SHALL NOT end the game.
8. A `solved` Puzzle SHALL NOT revert to another state, and re-applying its effects SHALL NOT duplicate Items or flags.
9. P9 (The Resonance Engine) SHALL depend on data gathered from at least three earlier Puzzles.
10. IF the player closes a Puzzle UI without solving it THEN the system SHALL preserve its in-progress state.
11. The game SHALL be completable in all three endings without any random element affecting puzzle solutions.
12. Puzzle solution data SHALL be defined in content assets, not duplicated in UI code.

### Requirement 6: Contextual Hints

**User Story:** As a player, I want contextual hints, so that I can get unstuck without spoiling the whole mystery.

#### Acceptance Criteria

1. The system SHALL offer a hint control reachable from every gameplay screen.
2. WHEN the player requests a hint THEN the Hint_Provider SHALL select the highest-priority unsolved available Puzzle in the current Room, or, if none, the next objective for the whole game.
3. Each Puzzle SHALL have exactly three authored hint tiers: Nudge (direction), Clue (specific object or idea), and Solution Outline (explicit steps).
4. WHEN the player requests another hint for the same target THEN the system SHALL advance one tier, up to tier three.
5. The system SHALL show hints as text in-game and SHALL NOT penalize the player's ending.
6. WHEN a hint is requested THEN the system SHALL record `hintsUsed` for that Puzzle in Game_State.
7. WHERE the selected Puzzle depends on an Item the player has not yet obtained, the hint SHALL point toward obtaining it first.
8. The authored Hint_Provider SHALL be deterministic: the same Game_State and request count SHALL produce identical text.
9. WHEN all puzzles in the current Room are solved THEN the hint SHALL guide the player toward the next unresolved Room or the ending.

### Requirement 7: Choices Affect the Story

**User Story:** As a player, I want my choices to affect the story, so that my decisions matter.

#### Acceptance Criteria

1. The game SHALL contain at least four Choice_Events, with at least two in the vertical slice-reachable content path and the final choice in the Echo Vault.
2. WHEN the player picks a Choice_Event option THEN the system SHALL apply that option's authored effects to Story_Flags and persist before continuing.
3. WHERE a Choice_Event has a precondition THEN the system SHALL hide or disable unavailable options and show a reason when disabled.
4. Story_Flags SHALL include at least: `mercy` (integer, 0–3), `truthFragments` (integer, 0–5), `acceptedBargain` (boolean), and `fate` (integer, 0–3, set by the final choice). Additional authored flags (for example `tallowHurt`, `echoAngered`, `maulPressed`, `cylinderPlayed`, `engineRestored`) are declared in `story.json`.
5. WHEN a Story_Flag changes THEN dialogue and descriptions that reference that flag SHALL reflect it on next display.
6. A Choice_Event SHALL be resolved only once; reloading a save SHALL NOT allow re-choosing it.
7. The Ending_Resolver SHALL use Story_Flags only and SHALL NOT use randomness or wall-clock time.

### Requirement 8: Save and Resume Progress

**User Story:** As a player, I want to save and resume progress, so that I can play in multiple sessions.

#### Acceptance Criteria

1. WHEN a Room transition, Item change, Puzzle state change, or Choice_Event resolution occurs THEN the system SHALL autosave Game_State.
2. WHEN the app moves to background or is paused THEN the system SHALL flush a pending save.
3. WHEN the player selects "Continue" THEN the system SHALL restore Game_State exactly, including room, inventory order, puzzle states, attempts, hints used, in-progress puzzle data, Story_Flags, and visited Rooms.
4. Save data SHALL include a `schemaVersion` integer.
5. WHEN loading a save with an older `schemaVersion` THEN the system SHALL migrate it to the current schema, or, if migration is impossible, offer to start a new adventure without deleting the old data.
6. IF a save is corrupt or fails validation THEN the system SHALL fall back to the last known-good backup, and if none exists SHALL show a recoverable error and disable "Continue" only.
7. The save write SHALL be atomic: an interruption during write SHALL NOT destroy the previous valid save.
8. After the full game ships THEN the system SHALL provide 3 manual save slots in addition to the autosave slot (post-slice).
9. WHEN a save is serialized and then deserialized THEN the resulting Game_State SHALL be equal to the original (round-trip property).
10. Save data SHALL NOT contain personal data, AI keys, or device identifiers.
11. The player SHALL be able to delete saves from Settings with confirmation.

### Requirement 9: Music, Sound, and Accessibility Settings

**User Story:** As a player, I want to control music, sound, and accessibility settings, so that the game is comfortable for me.

#### Acceptance Criteria

1. The Settings screen SHALL provide independent controls for music volume, sound-effects volume, and a master mute.
2. The Settings screen SHALL provide: reduced motion, high-contrast mode, text size (100%, 125%, 150%, 200%), "Highlight interactables", and optional dyslexia-friendly font spacing.
3. WHEN a setting is changed THEN the system SHALL apply it immediately without restart and persist it.
4. Settings SHALL persist independently from Game_State and survive "New Adventure" and save deletion.
5. WHEN the device or OS requests reduced motion THEN the system SHALL default reduced motion to enabled.
6. WHILE reduced motion is enabled THEN the system SHALL replace continuous animations (mist, flicker, parallax) with static or single-step alternatives and SHALL keep all gameplay functional.
7. IF audio fails to initialize or an asset is missing THEN the system SHALL continue without audio and SHALL NOT crash.
8. WHEN the app is backgrounded THEN the system SHALL pause audio and resume it on foreground.
9. The Settings screen SHALL include an AI-hints toggle that is visible only if AI is configured (Requirement 12).

### Requirement 10: Complete the Game Offline

**User Story:** As a player, I want to complete the game without internet access, so that I can play anywhere.

#### Acceptance Criteria

1. All story text, puzzle data, hints, art, and audio required for gameplay SHALL be bundled in the app.
2. WHILE the device has no network connectivity THEN the system SHALL allow completing all Puzzles and reaching all three endings.
3. WHEN AI is not configured THEN the system SHALL make zero network requests during gameplay.
4. The core game SHALL NOT depend on runtime font downloads or remote assets.
5. IF a network call fails or times out in optional features THEN the system SHALL silently use the deterministic fallback without blocking the UI.
6. The release build SHALL pass an offline test in which all network access is blocked and the full game is played to an ending (manual checklist or integration test with a throwing network client).

### Requirement 11: Three Distinct Endings

**User Story:** As a player, I want to reach three distinct endings, so that replaying the game feels worthwhile.

#### Acceptance Criteria

1. The game SHALL have exactly three endings: A Quiet Dawn, The Homecoming, and The Keeper's Chair.
2. The final choice (`c_echo_fate`) SHALL set the `fate` flag, and the Ending_Resolver SHALL evaluate ordered rules over story flags and return the first match, with A Quiet Dawn as the default:
   1. `fate == 3` → The Keeper's Chair
   2. `fate == 2` → The Homecoming
   3. otherwise → A Quiet Dawn
   The final options are gated so that endings are earned: "Call Ottoline home" requires `truthFragments >= 4`, `mercy >= 2`, and `acceptedBargain == 0`; "Claim the Echo" requires `acceptedBargain == 1`; "Let the Echo rest" is always enabled so completion can never be blocked.
3. Each ending SHALL have a unique epilogue text sequence, scene illustration, and music cue.
4. WHEN an ending is reached THEN the system SHALL display a results summary: ending name, puzzles solved, hints used, and choices made.
5. WHEN an ending is reached THEN the system SHALL record it in a persistent `endingsSeen` set stored in the settings/meta store.
6. WHEN the ending completes THEN the system SHALL let the player return to the title screen or start a new adventure.
7. Each ending SHALL be reachable by a documented, test-verified sequence of actions.
8. The Ending_Resolver SHALL be total: every possible Story_Flag combination SHALL map to exactly one ending.

### Requirement 12: Optional AI-Assisted Hints and Narrative

**User Story:** As a player, I want to optionally use AI-assisted hints or narrative enhancements when configured, so that hints feel more personal without being required.

#### Acceptance Criteria

1. The AI feature SHALL be disabled by default and SHALL be available only if a valid configuration (endpoint and credentials) is supplied at build time or by the user in Settings.
2. WHEN AI is not configured THEN the system SHALL hide all AI controls and use the authored Hint_Provider.
3. The AI_Service SHALL be able to rewrite an authored hint or narration line in the game's tone. It SHALL NOT modify Game_State, solve Puzzles, or select endings.
4. WHEN the player requests a hint with AI enabled THEN the system SHALL immediately make the authored hint available and MAY replace it with the AI-rewritten version if it arrives within 4 seconds.
5. IF the AI request fails, times out, returns empty text, fails validation, or the device is offline THEN the system SHALL display the authored text with no error dialog.
6. AI output SHALL be validated: plain text only, maximum 400 characters, no URLs, and not exceeding the authored hint tier's spoiler level (the prompt SHALL only include text up to the requested tier).
7. WHEN AI is first enabled THEN the system SHALL show a consent notice explaining what data is sent (current hint tier text and Room name only) and require explicit opt-in.
8. The system SHALL NOT send saves, device identifiers, or free-form player text to the AI_Service.
9. API credentials SHALL NOT be committed to the repository and SHALL NOT be written to Game_State.
10. The AI path SHALL be isolated behind an `AiService` interface so that removing the implementation leaves the game fully functional.
11. Narrative enhancements SHALL be cosmetic and limited to optional flavor lines shown alongside, never replacing, authored story text.
12. Every AI-using feature SHALL have a deterministic fallback implemented and tested.

### Requirement 13: Performance

**User Story:** As a player, I want the game to feel smooth and responsive, so that the atmosphere is not broken by lag.

#### Acceptance Criteria

1. The app SHALL reach an interactive title screen within 3 seconds of launch on a mid-range Android device (reference: 2020-era device with 4 GB RAM) in a release or profile build.
2. During gameplay and animated scenes THEN the system SHALL sustain at least 55 FPS on the reference device with no more than 5% of frames exceeding 16 ms build or raster time during a 60-second scripted playthrough.
3. WHEN the player taps a Hotspot THEN the first visual response SHALL appear within 150 ms.
4. A Room transition SHALL complete within 600 ms.
5. An autosave write SHALL complete in under 200 ms for a typical Game_State and SHALL NOT block the UI thread.
6. A serialized Game_State SHALL be under 100 KB.
7. The app SHALL use code-painted or compressed assets so that the release APK stays under 60 MB.
8. Animated painters SHALL be wrapped in repaint boundaries and SHALL stop when the app is not in the foreground.

### Requirement 14: Usability and Accessibility

**User Story:** As a player with varied abilities and devices, I want the game to be usable and accessible, so that I can enjoy it comfortably.

#### Acceptance Criteria

1. The UI SHALL adapt to compact (<600 dp), medium (600–1023 dp), and expanded (≥1024 dp) widths in portrait and landscape without overflow or clipped controls.
2. At every supported text size up to 200% THEN the system SHALL display all text without overflow or loss of function.
3. All text SHALL meet a 4.5:1 contrast ratio against its background in default mode, and 7:1 in high-contrast mode.
4. Information SHALL NOT be conveyed by color alone; puzzle feedback SHALL also use text or icons.
5. All interactive elements SHALL have semantic labels and a minimum 48×48 dp touch target.
6. All puzzles SHALL be completable with taps only; no puzzle SHALL require timed input, multi-touch, or precise dragging as the only method.
7. WHEN a screen reader is active THEN the player SHALL be able to navigate Room Hotspots as an ordered list and complete the vertical slice.
8. The system SHALL provide a short in-game tutorial of controls that is skippable and replayable from Settings.
9. IF the device rotates mid-puzzle THEN the system SHALL preserve puzzle input state.
10. The game SHALL NOT include flashing content faster than 3 flashes per second.
11. The system SHALL handle the Android back gesture by closing the topmost overlay, then prompting to pause/exit from a Room.

### Requirement 15: Vertical Slice as Minimum Deliverable

**User Story:** As a hackathon team, I want a fully playable vertical slice first, so that a complete demonstrable game exists early.

#### Acceptance Criteria

1. The vertical slice SHALL contain: title screen, new/continue flow, the Entrance Hall and Library (2 Rooms), puzzles P1, P2, and P3, at least one Choice_Event, inventory with inspect, tiered authored hints, autosave and resume, a settings screen with audio and accessibility options, and one complete ending.
2. The vertical slice SHALL be playable from title screen to an ending without crashes in a single session, offline.
3. The vertical slice SHALL use the same engine, data format, persistence, and UI architecture as the full game; no throw-away code.
4. The vertical slice SHALL pass `flutter analyze` with no issues and `flutter test` with no failures.
5. The vertical slice SHALL include a "slice ending" that is a temporary variant of an authored ending and SHALL be replaced by the real ending resolver in the full game without data-format changes.
6. WHEN the vertical slice milestone is reached THEN the team SHALL record a demo walkthrough script of the happy path.

### Requirement 16: Game State Model

**User Story:** As a developer, I want a clearly defined state model, so that gameplay, persistence, and tests share one source of truth.

#### Acceptance Criteria

1. Game_State SHALL contain: `schemaVersion`, `currentRoomId`, `visitedRoomIds`, `openExitIds`, `inventory` (ordered Item ids plus `inspectedItemIds`), `consumedItemIds`, `puzzleStates` (state, attempts, hintsUsed, puzzle-specific progress per Puzzle id), `examinedHotspotIds`, `storyFlags`, `resolvedChoiceIds`, `endingId` (nullable), `playTimeMs`, and `updatedAt`.
2. The application phase SHALL be one of: `booting`, `titleMenu`, `intro`, `exploring`, `puzzleActive`, `choiceActive`, `ending`, `paused`.
3. Phase transitions SHALL be restricted to a defined transition table; illegal transitions SHALL be rejected and logged in debug builds.
4. Game_State SHALL be immutable; every change SHALL produce a new instance through the Game_Engine.
5. Game_State SHALL be JSON-serializable using only primitive JSON types.
6. The Game_Engine SHALL expose each change as a named action and SHALL return a list of emitted events (for example `itemAcquired`, `puzzleSolved`) for UI and audio to react to.
7. Validation SHALL reject a Game_State that references unknown Room, Item, Puzzle, or Choice ids.

### Requirement 17: Content Originality and Licensing

**User Story:** As a hackathon participant, I want all content and dependencies to be properly licensed and original, so that the submission is legitimate.

#### Acceptance Criteria

1. All characters, story text, and visuals SHALL be original works created for this project.
2. Every third-party package and bundled asset SHALL have an entry in a `docs/LICENSES_AND_ASSETS.md` file noting name, version, license, and source.
3. Only assets with licenses permitting redistribution in an app (for example CC0, CC-BY, MIT, Apache-2.0, BSD) SHALL be bundled; CC-BY assets SHALL be credited in the About screen.
4. The About screen SHALL list credits and open-source licenses (via Flutter's license page).
5. Audio and art SHALL be generated procedurally, created by the team, or be CC0/properly attributed; no copyrighted or trademarked material SHALL be used.
6. The project SHALL record Kiro usage (specs, steering, hooks) in the repository and `.kiro` SHALL NOT be gitignored.

---

## Acceptance Test Matrix

Every main feature has at least one automated test (unit, widget, or integration) and one manual verification step.

| Req | Feature | Automated acceptance test | Manual verification |
|-----|---------|---------------------------|---------------------|
| 1 | New adventure | Widget: tapping New Adventure creates initial state in Entrance Hall; overwrite dialog appears when save exists; cancel preserves save | Start game, skip intro with one tap |
| 2 | Rooms | Unit: room graph connected and exactly five rooms; locked exit blocks movement; unlocking opens it. Widget: room transition updates `currentRoomId` | Visit all rooms, confirm distinct visuals |
| 3 | Hotspots | Unit: examine twice grants item once; use-rule success/failure. Widget: tap target ≥ 48 dp and semantics label | Tap every hotspot in each room |
| 4 | Inventory | Unit: add/consume/combine preserves order. Widget: inspect view opens; 20 items at 200% text scale no overflow | Collect and inspect all items |
| 5 | Puzzles | Unit per puzzle (P1–P9): correct, incorrect, partial; state machine never regresses; effects idempotent | Solve every puzzle on device |
| 6 | Hints | Unit: tier escalation, determinism, target selection, item-first rule. Widget: hint button on every gameplay screen | Request 3 tiers on one puzzle |
| 7 | Choices | Unit: option effects, one-time resolution, disabled-option reason | Make opposite choices in two runs, see different text |
| 8 | Save/resume | Unit: round-trip equality; migration; corrupt save falls back to backup; atomic write simulated failure. Widget: Continue restores room | Force-close app mid-game and continue |
| 9 | Settings | Unit: settings persistence independent of saves. Widget: sliders and toggles apply immediately; reduced motion disables animation | Change every setting on device |
| 10 | Offline | Integration: scripted playthrough with a throwing network client reaches an ending; zero network calls when AI unconfigured | Airplane-mode playthrough |
| 11 | Endings | Unit: resolver table-driven test over all flag combinations returns exactly one ending; three scripted playthroughs reach each ending | Play to each ending |
| 12 | Optional AI | Unit: fake AI success replaces hint; failure, timeout, empty, URL, over-length each fall back; no state mutation; consent required | Run with and without configuration |
| 13 | Performance | Profile-mode scripted run recorded with frame timings; save timing test | Check on reference device |
| 14 | Accessibility | Widget: text scale 200% no overflow at three widths; semantics tree contains labeled hotspots; contrast helper test on palette | TalkBack pass on slice |
| 15 | Vertical slice | Integration: title → P1 → P2 → P3 → choice → ending offline | Demo walkthrough |
| 16 | State model | Unit: transition table, immutability, validation of unknown ids | — |
| 17 | Licensing | CI/script check: every pubspec dependency and asset file listed in LICENSES_AND_ASSETS.md | Review About screen |
