# HauntQuest AI

An original dark-fantasy mystery adventure game built with Flutter, created for
the Kiroween 2026 hackathon (Costume Contest category) using Kiro IDE.

All characters, environments, stories, and artwork are original. Every
illustration is drawn in code; no image files are bundled.

## Status

Playable. Done:

- Full story content (five rooms, ten items, sixteen puzzles, seven linked dialogue
  scenes, three endings) with automated validation.
- The game interface: splash, main menu, save slots, illustrated room
  exploration, inventory, puzzle screens, dialogue, journal and evidence board,
  settings, and endings.
- A pure-Dart game engine: move between rooms, examine and collect, use items,
  solve puzzles, hold conversations that set story flags, and reach all three
  endings. Locked doors explain themselves with a nudge, not the answer.
- Puzzle inputs, attempts, hint tiers, solved states, and rewards persist to the device.
- Display and accessibility settings apply immediately and are saved.

Original procedural ambience and feedback sounds are bundled locally. The echo
frequency puzzle also includes visual pulses and written pitch clues, so every
puzzle remains playable muted. Review mode reveals the manor for inspection.

## The story

A letter from a frightened apprentice calls you to The Whispering Manor, where
the inventor Ottoline Vask vanished while chasing a phenomenon called the Echo.
Investigate, restore her Resonance Engine, and decide the Echo's fate. The
dependency map is in `docs/PROGRESSION_GRAPH.md`.

## Playable puzzles

Every puzzle requires a deliberate submission, provides contextual feedback and
three hint tiers, and supports reopening without repeating rewards. Reset clears
the apparatus while retaining attempts and revealed hints. All configurations are
fixed and validated offline; no puzzle depends on an API or random generation.

| Room | Puzzles |
| --- | --- |
| Moonlit Entrance Hall | Candle Moons; Wake the Caretaker; The Symbol Seal (substitution); The Silver Mirror (reflected grid) |
| Forgotten Library | The Whispering Shelf (cipher); Torn Recipe; The Missing Runes (sequence gaps); The Evidence Board (deduction timeline) |
| Alchemist's Workshop | Resonance Tuner; Corroded Cabinet; Moonwater Alchemy (ordered ingredients) |
| Clocktower Chamber | Stopped Hands (11:40 clock alignment); Drive Gears; Constellation Discs (compass alignment) |
| The Echo Vault | The Resonance Engine; The Echo Frequencies (pulse response) |

The added apparatuses require earlier story discoveries and carried clue items.
Their completed inscriptions reveal persistent story memories. Ingredients for
the alchemy retort are supplied at the bench and are never depleted by mistakes.

Tests include positive and negative cases for every puzzle, exhaustive solution
uniqueness checks, seeded randomized state transitions, save/reload and duplicate
reward checks, real Flutter interactions, and progression through all endings.

## Narrative and endings

Dialogue branches live in `assets/content/choices.json`. `NarrativeEngine` evaluates
availability, reactions, transcripts and discoveries independently of Flutter.
Choices resolve once; linked scenes share node IDs, and revisits are read-only
transcripts of the exact exchange heard. Final decisions cannot be replayed.
Leaving a conversation preserves it for later in the journal's Story tab.

The journal contains seventeen persistent discoveries and nine authored evidence
connections. Connections appear only after both clues are discovered. Consumed
items remain part of the investigation. Dialogue text supports tap-to-complete,
a labeled “Show full text” button, screen readers, and reduced motion.

| Ending | Requirements |
| --- | --- |
| Release the Echo | Restore the Resonance Engine, then choose freedom. Always available at the final decision. |
| Seal the Echo | Restore the engine; learn the binding words, or complete Moonwater Alchemy and Constellation Discs. |
| Become the Echo's Guardian | Restore the engine; learn four truths; show kindness twice; reject ownership; promise to listen; solve the Evidence Board and Echo Frequencies. |

Each ending has its own illustrated scene and finite reveal: rising lights for
release, closing containment rings for sealing, and an open arch with two free
lights for guardianship. Reveals are skippable and settle immediately with reduced
motion. Completed autosaves can reopen their earned ending.

Validation checks narrative references, duplicate IDs, continuation cycles,
unreachable scenes, journal references and every valid choice branch. Legacy saves
migrate previous ending IDs and retain progress while scheduling new follow-ups.
The compiled integration test plays from arrival through all five rooms to an
ending using only player controls; it does not inject flags or use review mode.

## The Whispering Guide

Open the flare icon in a room, puzzle, or journal. The optional companion explains
discovered evidence and offers **subtle → guided → direct** hints. Its local hint
progression does not count puzzle attempts, reveal the puzzle screen's hints,
modify inventory, resolve choices, award rewards, or write to the game save.
Closing the panel resets its companion-only session; the real game is unchanged.

| Capability | Shipped implementation |
| --- | --- |
| Contextual hints and evidence explanations | Deterministic, authored rules; fully offline. |
| Discovery and spoiler filtering | Local rules based on the current room, encountered puzzles, acquired clues, recorded conversations, and puzzle progress. |
| AI-generated prose | **Not enabled or displayed.** No live AI service is configured. |
| Optional AI assistance | Provider-neutral interface for selecting approved passages; no remote implementation or vendor SDK is shipped. |

Unseen puzzles and undiscovered evidence are absent from the focus list. Puzzle
answer tiers remain locked until their clues and prerequisites are known. Merely
examining a phonograph does not reveal its unheard recording. Evidence connections
require both endpoints to be discovered. The companion never reads unchosen
conversation options, ending rules, or future epilogues to construct guidance.

`OfflineGuide` builds an immutable passage allowlist for one topic and hint level.
`GuideService` optionally asks a configured `GuideProvider` to select from it. The
provider receives only the intent, level and at most three approved passages with
opaque local IDs—no save, full inventory, flags, choice history, player identifier,
or free-form player input. Its only accepted response is:

```json
{"passageIds": ["p0"]}
```

At most two unique supplied IDs are accepted. Unknown IDs, extra fields, model
prose, commands and malformed responses are rejected. Only exact local passage
text can reach the panel, so a provider cannot invent spoilers or escalate the
requested hint level. This constraint is deliberate: unrestricted generated prose
cannot reliably be proven spoiler-free. Successful optional assistance is labeled
**AI-assisted selection**, never AI-written narration.

To add a real provider later, supply `guideProvider` to `AppServices.create` only
after a suitable service is configured. Its adapter must call an authenticated
backend proxy over HTTPS; model credentials belong in backend secret storage,
never Dart code, assets, client headers or client build defines. No API key or
endpoint is required for the shipped game. Optional assistance is off by default
and requires the player's opt-in before any provider call. Turning it on does not
itself send a request.

Offline hints appear immediately. Optional requests have a three-second deadline;
timeouts, failures and invalid responses retain the offline hint without exposing
backend error text. Late responses are ignored after the room, discoveries,
focus, consent or panel lifetime changes. The companion has no authoritative
mutation capability; no provider result is interpreted as a game action.

Tests cover discovery filtering, poisoned unseen story text, all hint levels,
recording prerequisites, opt-in, failures, timeouts, malformed responses, stale
requests, immutable requests, minimal payloads, 250 seeded adversarial selections,
unchanged saves, and accessible phone/tablet layouts at enlarged text sizes.

## Saves, sound and final effects

Autosave schema **v2** stores the room, visited rooms, inventory and acquired/used
items, exits, solved puzzles, drafts and attempts, dialogue flags and transcripts,
pending conversations, discovered journal entry IDs, and ending status. Supported
v1 saves migrate to v2, retaining legacy ending-ID migration and new follow-ups.
Future-version saves are preserved and protected from automatic overwrite.

Each local save uses an inactive, checksummed snapshot slot. The entire snapshot
is written and verified before switching the commit pointer; the previous complete
snapshot remains available as a backup. Reads verify checksums, required fields,
content references, item integrity, room connectivity, rewards and final-decision
agreement before accepting a state. Corrupt, incomplete or unsupported data never
partially populates the game. Settings use the same alternating-slot mechanism.
Writes are serialized, save failures are visible and retryable, and confirmed New
Game waits behind older writes before clearing and saving the fresh journey.
Continue and ending screens share the same New Game confirmation. Backgrounding
flushes pending progress and persists current settings.

Twenty original sound assets are synthesized by `tool/generate_audio.py` using only
standard-library oscillators and deterministic noise—no music, recordings, external
samples or downloads. Five eight-second room loops are joined by pickup, unlock,
success, failure, footstep, discovery, chapter, interaction, three ending and four
echo-frequency effects. Regenerate with `python3 tool/generate_audio.py`.
The entire audio asset set is about 1.7 MB of 16 kHz, mono 16-bit PCM.

Playback uses [audioplayers](https://pub.dev/packages/audioplayers), with one ambient
player and a fixed three-voice effects pool. There is no position polling or
runtime synthesis. Settings provide master, ambient and effects volume plus mute;
slider changes apply immediately and commit on release. Audio stops when inactive,
hidden or paused, resumes only ambient sound on foregrounding, respects iOS silent
mode and Android audio focus, and releases resources when the app closes. Audio
failures cannot change progression or stop the player completing a puzzle.

Fog, lighting, room/page transitions, object press feedback and ending ceremonies
are joined by finite discovery/unlock/puzzle bursts. Decorative discovery rays now
settle instead of looping forever. The room background is static-cached while
foreground ambience animates. A root lifecycle `TickerMode` mutes gameplay tickers
in the background; reduced motion disables continuous motion and particle bursts.
Native audio and Flutter controllers are explicitly disposed.

Remaining limitations: the three **manual save slots** are placeholders; functional
persistence is the active autosave plus its recovery backup. Mid-range Android
FPS, real-device audio interruptions/headphone routing, and iOS hardware playback
still need physical-device profiling; unit tests and
build checks do not establish a sustained frame-rate guarantee. Local preference
storage and two recovery slots reduce corruption risk but cannot guarantee survival
of a device/storage failure that destroys every copy. The latest macOS native
playthrough could not complete in this desktop session because the runner failed
to foreground its window; rerun it with the app active. Unit/widget traversal and
the Android debug build pass.

## Targets

- Android (primary; verified on an emulator with an integration test)
- Flutter Web (release build verified)

## Structure

```
lib/
  app/            App root, services, settings, GameController
  core/
    design/       Tokens, theme extension, motion policy
    theme/        Colors and ThemeData
    painting/     All code-drawn art (rooms, objects, items, portraits, endings)
    widgets/      Shared components (buttons, panels, fog, grain, typewriter)
    navigation/   Page transition
  content/        Pure-Dart content models, loader, and validation
  domain/         Game state, engine, hints, puzzle evaluators (pure Dart)
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
flutter test integration_test -d <device>   # complete five-room journey to an ending
```

## Kiro hooks

Agent hooks in `.kiro/hooks/` check formatting and analysis after Dart edits, keep `.kiro/` tracked in Git, and block agent commits that contain obvious secrets or build artifacts. See `docs/KIRO_WORKFLOW.md`. Before committing from a terminal, run `sh tool/hooks/run.sh scan`.

A read-only custom agent, `.kiro/agents/game-quality-agent.md`, reviews puzzle solvability, accessibility, architecture and test coverage on request. What was used (and what was not: no MCP servers, no Powers) is in `docs/KIRO_ADVANCED_FEATURES.md`.
