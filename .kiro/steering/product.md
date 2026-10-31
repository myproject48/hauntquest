# Product: HauntQuest AI

## Vision

HauntQuest AI is an original, atmospheric mystery adventure. The player is called by a letter from a frightened apprentice to **The Whispering Manor** (Vask Manor), where the inventor Ottoline Vask vanished while investigating a phenomenon called the Echo. They examine objects, collect clues, solve puzzles, restore the Resonance Engine, decide the Echo's fate, and reach one of three endings. The tone is eerie and melancholy, not gory.

All characters, story, art, and audio are original. Never borrow characters, settings, names, or text from existing franchises.

## Target Audience

- Casual-to-core mobile players who enjoy short, thoughtful puzzle-adventure sessions (10-30 minutes per sitting, roughly 60-90 minutes total).
- Players who like atmosphere and story over reflex challenges.
- Players with accessibility needs. The game must be playable with taps only, with no timed input.
- Hackathon judges and reviewers who will play a short demo, often on a phone or in Chrome.

## Core Gameplay Loop

1. **Look**: scan the room, tap objects (hotspots) to read descriptions.
2. **Collect**: pick up items and clues; inspect them in the inventory.
3. **Connect**: combine clues and items to understand puzzles.
4. **Solve**: complete a puzzle to open exits, grant items, and reveal truth fragments.
5. **Decide**: make narrative choices that change mercy and truth flags.
6. **Resolve**: reach one of three endings determined by story flags.

Progress is saved automatically. Hints are always available and never punish the player.

## Story Structure (see the spec for details)

- Five rooms: Moonlit Entrance Hall, Forgotten Library, Alchemist's Workshop, Clocktower Chamber, The Echo Vault.
- Voices: Tallow (clockwork caretaker), Ottoline Vask (inventor, recordings), Wren Dabney (apprentice, letter), Edric Maul (investor who sabotaged the engine), the Echo.
- Nine puzzles (P1-P9), ten items, and four dialogue choices that set persistent story flags.
- Three endings: A Quiet Dawn (release), The Homecoming (call Ottoline home, earned by truth and mercy), The Keeper's Chair (claim the Echo, after Maul's bargain). "Release" is always available, so the game can always be finished.
- Content is data: `assets/content/*.json`, validated by `ContentValidator`. Dependency map: `docs/PROGRESSION_GRAPH.md`.

## Optional AI

AI is an optional enhancement that may rephrase hints or add flavor lines. The game must be fully playable and complete without it, offline, and with an authored deterministic fallback for every AI feature. AI never changes game state, solves puzzles, or selects endings.

## Hackathon Focus: Kiroween 2026, Costume Contest

- The "costume" is the haunted, hand-crafted dark-fantasy look. The theme and visual identity are the product's showpiece, so polish visuals, animation, and mood.
- Everything must be original and created during the submission period (from October 30, 2026, 9:00 AM Pacific).
- Kiro must be used visibly throughout development: specs, steering, and hooks live in `.kiro/` and are committed to version control. Never gitignore `.kiro/`.
- Submission and player-facing text are in English.
- A complete, playable, demo-ready vertical slice takes priority over breadth. See the milestone in the spec's `tasks.md`.

## Current Status (keep this section truthful)

- Done: project foundation, the Kiro spec, the narrative content with validation, pure puzzle evaluators, and the full game interface (splash, menu, save slots, intro, room exploration, inventory, puzzles, dialogue, journal and evidence board, settings, endings, credits) with original code-drawn art. Display and accessibility settings persist.
- Not done: the game engine and game state (rewards, opening exits, recording choices, ending resolution from play), saving progress, audio, and AI. The UI runs on a read-only `PreviewController` and labels these limits on screen. Do not describe them as existing until implemented.

Source of truth for scope: `.kiro/specs/hauntquest-ai-game/` (requirements.md, design.md, tasks.md).
