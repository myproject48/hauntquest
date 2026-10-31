# Quality Standards

These rules apply to every task and every change.

## Non-Negotiables

1. **No unfinished buttons.** Every visible button, tile, and hotspot must do something real or be removed or clearly disabled with a reason. Exception: a temporary control may exist only while its task is in progress and must be recorded in the Known Gaps list below.
2. **No inaccessible game progression.** Every puzzle, item, and ending must be reachable by tap alone, with screen reader support, at 200% text scale, and without timing. No dead ends: from any reachable state the player can still finish (hints must always be able to point forward).
3. **No hardcoded secrets.** No API keys, tokens, or endpoints with credentials in source, assets, saves, logs, or docs. Use `--dart-define` or user-entered settings stored locally.
4. **No silent failures.** Do not swallow exceptions with empty `catch`. Either handle with a defined fallback and a debug log, surface a recoverable message, or rethrow. Optional features (audio, AI) may degrade gracefully but must log a debug message. Engine rejects return `ActionRejected`, not nothing.
5. **No placeholder gameplay presented as complete.** Placeholders must be labeled in code (`TODO(task N)`), absent from release-facing text, and listed in Known Gaps. README, About, and demo text must describe only what works.
6. **Analysis and tests after major changes.** After any meaningful change run `flutter analyze` (zero issues) and `flutter test` (all passing) and fix failures before reporting done. Checkpoints in `tasks.md` are mandatory.
7. **Reasonable performance on mid-range phones.** Target at least 55 FPS, cold start under 3 s, hotspot feedback under 150 ms, room transition under 600 ms, autosave under 200 ms off the UI path, save size under 100 KB. Avoid per-frame allocations in painters; use `RepaintBoundary`; do heavy work outside `build`.
8. **Reduced-motion accommodations.** All continuous or large animations check the motion policy (OS flag and in-app setting). Gameplay must be fully functional with motion off.
9. **Original or properly licensed assets only.** Every dependency and every file under `assets/` has an entry in `docs/LICENSES_AND_ASSETS.md`. CC-BY content is credited in-game. No copyrighted or trademarked material.

## Definition of Done for a Task

- Implements the task's stated requirements (reference the numbers in `tasks.md`).
- Has tests at the right level (unit for domain, widget for UI) unless the task is docs-only.
- `flutter analyze` clean; `flutter test` passing.
- Works at 360 dp portrait and one larger width; no overflow at 200% text scale.
- No new unfinished controls, silent catches, or secrets.
- `tasks.md` checkbox updated only when verified. README and steering Status sections stay truthful.
- Reported result states what was verified and what was not (for example "not run on an Android device").

## Code Review Checklist

- Domain code has no Flutter imports; widgets do not contain game rules.
- Puzzle solutions are in content data, not widgets.
- Models are immutable; saves round-trip.
- AI paths are optional, validated, time-limited, and have a deterministic fallback.
- No network call occurs when AI is unconfigured.
- Semantics labels and 48 dp targets are present on new interactive elements.
- Colors come from `AppColors`; text styles from the theme.

## Known Gaps (update as work progresses)

- The UI runs on `PreviewController` (read-only). Solving a puzzle shows the verdict but grants nothing; dialogue answers are not recorded; only the starting exits open. Each screen says so. Replace with the real `GameController` (tasks.md 4 to 10).
- "Continue" opens save slots that are honestly empty: saving is not built.
- Settings > Review tools (reveal everything, preview endings) is a review aid, not gameplay. Remove or hide it before release.
- There is no audio; the Settings "Sound" section says so instead of showing dead sliders.
- The content is validated but not playtested by a human. Clue wording and puzzle difficulty need real play on a device.
- Not yet run on an Android device or emulator. A Flutter Web release build succeeds.
- Slice scope needs a decision: the story chains through all five rooms (tasks.md 17.0).
- Android build and device testing have not been run (no device connected so far).
