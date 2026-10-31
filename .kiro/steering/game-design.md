# Game Design Guidelines

## Aesthetic: Original Dark Fantasy

- Moody, moonlit, melancholic. Spooky but gentle: no gore, no jump-scare flashes.
- Art is original and code-painted (`CustomPainter`, gradients, glows, silhouettes) in `lib/core/painting/`. `ExteriorScene` and `RoomArt` are the reference style. Every new hotspot, item icon, character, scene or sigil id needs art; `test/ui/responsive_test.dart` fails otherwise.
- Rooms are drawn in three parallax layers (back, mid with objects, front) inside a fixed 3:4 stage, with fog and film grain between. Interactive objects are drawn exactly inside their hotspot rectangles, so what you see is what you can tap.
- Text set inside art (plaques, stamped letters) is painted with `Kit.text`. All other text uses theme styles.
- No imitation of existing franchises, characters, or recognizable settings.

## Design Tokens

Colors live in `lib/core/theme/app_colors.dart`. Use tokens, never raw hex in features.

| Token | Value | Use |
|-------|-------|-----|
| `midnight` | `#050818` | Deepest background |
| `navy` | `#0A1030` | Surface |
| `deepNavy` | `#111A45` | Panels, button gradient |
| `deepPurple` | `#2B1357` | Sky/panel accent |
| `violetMist` | `#4A2A86` | Highlights on purple |
| `moonCyan` | `#8DEBF5` | Primary accent: moon, focus, interactables |
| `ghostGreen` | `#9BFFC8` | Secondary accent: spirit, mist, success |
| `antiqueGold` | `#D1A94F` | Tertiary accent: borders, titles, buttons |
| `parchment` | `#EDE6D3` | Primary text |
| `fog` | `#A9B0CF` | Secondary text |
| `danger` | `#FF7A8A` | Errors, never the only signal |

- Add new tokens to `AppColors` rather than inlining colors. Add a high-contrast variant when the high-contrast setting is built.
- Typography: system serif stack (`Georgia`, fallback `Times New Roman`, `serif`) set in `AppTheme`. No runtime font downloads. If a custom font is added, it must be OFL or Apache licensed and bundled.
- Type scale from `AppTheme`: display (title, wide letter spacing), titleLarge, bodyMedium (16, line height 1.5), labelLarge (button, uppercase, letter spacing 2). Use theme text styles, not ad hoc sizes.
- Spacing: multiples of 4 dp. Corner radius 14 for buttons and panels. Gold 1.5 px borders with soft glow for primary actions.

## Interaction Principles

- Tap-only. No timed input, no precision dragging, no multi-touch requirement.
- Every tap gets visible feedback within 150 ms (glow pulse, highlight, short text, or state change).
- Minimum 48x48 dp touch targets. Keep visuals small if needed, but expand the hit area.
- One overlay at a time. Back gesture closes the top overlay first.
- Wrong puzzle answers are gentle: explain what is off with text and an icon, never punish or end the game.
- Hints are always available and escalate in three tiers (nudge, clue, solution outline).

## Animation Principles

- Fluid and atmospheric: slow mist drift, star twinkle, moon pulse, window flicker, short fades for room transitions (under 600 ms).
- Animations support mood or feedback; never block input.
- No flashing faster than 3 Hz.
- Honor reduced motion (OS flag or in-app setting): replace continuous animation with static scenes and instant or single-step transitions. Always check `MotionPolicy.reduceOf(context)`, which combines both. Programmatic scrolling must jump, not animate, when motion is reduced.
- Wrap animated painters in `RepaintBoundary`; stop them when the app is backgrounded.

## Meaningful Visual Feedback

- Item pickup: toast plus inventory highlight.
- Puzzle verdicts: correct (ghostGreen glow and icon), partial (gold, "almost" text), incorrect (danger tone plus icon and text).
- Locked exits: short in-world message that never reveals the solution.
- State changes persist visibly: solved puzzles, opened doors, and taken items must show when a room is revisited.

## Environmental Storytelling per Room

Each room needs its own palette emphasis, ambient cue, and at least three hotspots that tell part of Ottoline Vask's story without exposition dumps. Room ids, moods, and ambient cues come from `assets/content/rooms.json`.

| Room (id) | Mood token | Storytelling elements |
|-----------|-----------|-----------------------|
| Moonlit Entrance Hall (`moonlit_hall`) | `moonCyan` | Sealed door with frost, portrait with a key, four moon candles, dormant caretaker Tallow, a guest ledger already signed in your hand |
| Forgotten Library (`forgotten_library`) | `antiqueGold` | Dark until Tallow's lantern, Ottoline's journal, a cipher shelf, burned recipe page, Edric Maul's ledger |
| Alchemist's Workshop (`alchemist_workshop`) | `ghostGreen` | Corroded cabinet, phonograph with Ottoline's recording, resonance tuner, a speaking horn that answers |
| Clocktower Chamber (`clocktower_chamber`) | `antiqueGold` | Stopped clock at the hour she vanished, drive gears, keeper's logbook, Maul's voice in the speaking tube |
| The Echo Vault (`echo_vault`) | `violetMist` | Mirrored walls that reflect late, the dormant Resonance Engine, the Echo itself |

Voices have distinct writing guidance in `story.json` (`characters[].voice`). Follow it: Tallow is courteous and dry, Ottoline brisk and warm, Wren anxious and short, Maul silky with a price, the Echo repeats and bends the last words it hears.

Narrative text is original, English, concise for mobile (see the limits in `ContentValidator`), and written in a restrained, evocative voice.

## Accessibility and Readable Text

- Contrast: at least 4.5:1 in default mode, 7:1 in high-contrast mode. Verify the palette with a contrast helper test.
- Body text 16 sp minimum, line height about 1.5, left-aligned for paragraphs. Support text scaling up to 200% without overflow.
- Never convey information by color alone.
- Semantic labels on all interactive elements; hotspots also available as an ordered list for screen readers.
- Text over scenes sits on a panel with sufficient opacity.
- Optional spaced-text setting for dyslexia support.

## Mobile-First Responsive Layout

- Design for a 360 dp wide portrait phone first, then scale up.
- Use `Responsive.of(context)` classes: compact (<600), medium (600-1023), expanded (>=1024). Cap content width (`Responsive.maxContentWidth` for menus).
- Use `SafeArea`, scroll containers, `Wrap`, and `Flexible`. No fixed pixel layouts tied to one device.
- For "top and bottom" screens (menu, splash, ending) use `FillOrScroll`. Do not use `IntrinsicHeight` or `SliverFillRemaining(hasScrollBody: false)`: they measure wrapped text at the wrong width and overflow at 200% text.
- Keep HUD and overlays off interactive objects. Hotspots near the top edge must start at y ≥ 0.12 so their markers clear the HUD buttons.
- Portrait and landscape must both work; rotation preserves puzzle input.
- Tablets and web show the scene centered with side panels instead of stretched art.
