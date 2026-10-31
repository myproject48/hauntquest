# HauntQuest AI

**Category:** Costume Contest

## Elevator pitch

A spooky Flutter adventure where players explore a haunted manor, solve mysterious puzzles, and shape the Echo's fate through interactive storytelling—with contextual offline hints.

## Final project description

A letter from a frightened apprentice brings you to the Whispering Manor. Its
inventor, Ottoline Vask, has disappeared, and a presence called the Echo remembers
more than it can explain. To uncover what happened, you must examine the manor's
objects, connect its evidence, restore the Resonance Engine and decide whether
the Echo should be released, sealed away or protected by a guardian.

HauntQuest AI is an offline Flutter mystery adventure with five illustrated rooms,
sixteen playable puzzles, an inventory, a discovery journal, an evidence board and
branching conversations. Clues come from letters, inscriptions, recordings and
objects in the world. Puzzles require deliberate player input, explain incorrect
answers and offer three levels of help. Earlier discoveries and decisions affect
the final options; revisiting a solved puzzle preserves progress without repeating
its rewards.

The haunted atmosphere is built into the interface: original illustrations drawn
in code, character portraits, parchment-like reading panels, fog and lighting,
responsive object feedback, locally synthesized sound and distinct ending reveals.
Reduced motion, text controls, high contrast and mute settings make that atmosphere
adjustable. Pitch-based puzzles also provide written and visual clues.

The optional Whispering Guide explains discovered evidence and offers contextual
hints. **In this release it is rule-based and fully offline; no live AI service or
AI-generated dialogue is enabled.** Kiro contributed to the development workflow,
with the specs, steering, hooks and custom-agent configuration retained in the
repository. The game itself needs no account, API key or network connection.

Android is the primary submission platform. A release-mode evaluation APK has been
built, and a compiled Android integration test has played from arrival through
all five rooms to the Release the Echo ending using normal player controls.

## Inspiration

The design takes inspiration from haunted-house mysteries, escape-room reasoning
and illustrated storybooks: ordinary objects become evidence when their meaning
changes in context. A clock is an instrument and a memory; a broken recipe is a
puzzle and a trace of the person who wrote it.

The aim was to make a spooky interface support investigation rather than obscure
it. Players should be able to linger over a clue, ask for help and make a considered
choice without a timer or an internet connection interrupting the story.

## What it does

Players explore the Moonlit Entrance Hall, Forgotten Library, Alchemist's Workshop,
Clocktower Chamber and Echo Vault. They collect and inspect clues, use items on
objects, combine recipe pages, solve apparatuses and speak with Tallow and the
voices connected to Ottoline's disappearance.

The sixteen puzzles include moon sequences, a substitution seal, a reflected grid,
a Caesar cipher, missing runes, an evidence timeline, alchemy, a tuner, clock hands,
gears, constellation discs and an echo-frequency pattern. Each has visible clue
sources and deterministic validation. The inventory and journal preserve what has
been learned, while evidence connections appear when their clues are discovered.

Dialogue choices are remembered. The final decision offers **Release the Echo**,
**Seal the Echo**, or **Become the Echo's Guardian**, subject to completed story
requirements. Progress and unfinished puzzle inputs autosave locally. Continue
restores the journey, including its earned ending; New Game asks before replacing it.

## How it was built

Flutter and Dart provide the Android application and its interface. Original room,
object, portrait and ending illustrations are painted with Flutter's CustomPainter.
Story, room, item, puzzle and dialogue definitions live in local JSON assets.

A pure-Dart engine owns inventory, legal actions, puzzle completion, narrative
flags and endings. Flutter screens display its results rather than implement
separate game rules. Content validation checks references and progression; tests
exercise puzzle answers, narrative branches, state invariants and save integrity.

Device storage uses shared_preferences behind validated, versioned snapshots with
checksums and a recovery copy. Audioplayers plays original local WAV assets generated
with a Python script. Settings control sound and motion; lifecycle handling pauses
unnecessary animation and audio in the background.

Kiro workflow artifacts document the specification, design constraints and checks.
The separate Kiro write-up explains exactly what is retained and what is not claimed.
No remote AI provider or backend is required for the submitted game.

## Challenges faced

The main implementation challenges were keeping investigation state consistent
across revisits, preserving a complete journey during failed or interrupted saves,
and making branching endings reachable without letting dialogue presentation
control the story rules. Immutable state, idempotent rewards, strict save validation
and declarative narrative conditions address those requirements.

Another challenge was balancing atmosphere with clarity. Dark artwork still needs
readable clues and clear controls. Motion and sound need alternatives, so the game
includes reduced motion, text adjustments and visual equivalents for frequency cues.
The companion also has to help without revealing unseen branches; its guidance is
restricted to authored passages supported by the player's discoveries.

Keeping the release description honest was part of the work: the original design
changed, and a provider interface must not be advertised as a live AI service.

## What was learned

Separating authoritative rules from presentation makes a narrative game easier
to validate: the same engine can drive Flutter controls and legal playthrough tests.
A content graph can reveal broken references, while randomized state sequences
exercise combinations that individual answer tests do not cover.

Accessibility also changes the design of a puzzle, not just its settings screen.
A pitch challenge becomes more dependable when its pattern is expressed in text
and light as well as sound. Finally, a modest offline companion can be useful
without introducing unpredictable generated text into progression.

## Accomplishments

- A complete five-room investigation has been demonstrated on an Android emulator
  from the beginning to an earned ending without developer state injection.
- Sixteen puzzles have playable Flutter controls and positive/negative validation
  coverage; automated narrative tests establish that all three endings are attainable.
- The November 1 release validation recorded **394 passing tests** and clean
  `flutter analyze`, plus passing Android gameplay and preference-reload integration tests.
- Original code-drawn art, original synthesized sound and distinct ending reveals
  give the game a consistent haunted identity.
- A release-mode APK and Web release build were produced. The APK is an evaluation
  build signed with a development certificate, not a claimed Play Store release.

These results describe the recorded checks, not physical-device frame-rate measurements,
human usability metrics or proof of three separate native-device ending recordings.

## What's next

The next steps are broader human playtesting, physical Android device profiling,
TalkBack and audio-interruption checks, and verification on older supported Android
versions. Public distribution needs an approved repository/build host and a durable
signing identity. Localization and additional investigations are possible future
work, not shipped features.

A future optional remote companion would require consent, a backend proxy for
secrets, strict spoiler limits and an offline fallback. It is not necessary to
finish the current adventure and is not enabled in this submission build.

## Built With

Suggested Devpost technology tags:

`Flutter`, `Dart`, `Kiro`, `Android`, `CustomPainter`, `JSON`,
`shared_preferences`, `audioplayers`, `Python`

Do not add model-provider, cloud database or backend tags: none is used by the
shipped gameplay. Web is a secondary build target; Android is the demonstrated
submission target.

## Why Costume Contest

The game's “costume” is a cohesive haunted interface that also serves the mystery.
Illustrated objects invite inspection; the inventory and journal turn discoveries
into readable evidence; character portraits frame consequential dialogue; and
instrument-like puzzle controls connect clues to the environment. Each room has
its own visual scene and ambience while sharing the same design language.

Discovery flashes, puzzle feedback and ending ceremonies make the consequences of
player actions visible. Reduced motion, mute and reading controls let players
adjust the presentation while keeping the investigation playable. The submission
emphasizes this functional visual identity through actual Android gameplay footage.
