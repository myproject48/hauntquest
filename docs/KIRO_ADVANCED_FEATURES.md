# Kiro Advanced Features

This document records which advanced Kiro features this project actually uses, how they are configured, what was done with them, and what they found. Anything that was checked but not available or not used says so explicitly.

Environment: Kiro IDE 1.4.62 on macOS, Flutter 3.47.7, Dart 3.13.5. Checked on October 31, 2026.

Related: hooks and steering are documented in [KIRO_WORKFLOW.md](KIRO_WORKFLOW.md). The spec lives in `.kiro/specs/hauntquest-ai-game/`.

## Summary

| Feature | Status | Where |
|---|---|---|
| Custom agent | Used. Created and invoked twice | `.kiro/agents/game-quality-agent.md` |
| Skill (`security-audit`) | Used. Focused review in guidance mode; two guard bypasses found and fixed | `~/.kiro/skills/security-audit/` (user level, not in repo) |
| Agent hooks (v2) | Used, see KIRO_WORKFLOW.md | `.kiro/hooks/*.json`, `tool/hooks/` |
| Steering, specs | Used, see KIRO_WORKFLOW.md | `.kiro/steering/`, `.kiro/specs/` |
| MCP servers | Not used. None configured, none installed | n/a |
| Kiro Powers | Not used. None installed, none relevant in the registry | n/a |

## 1. Custom agent: Game Quality Agent

### Configuration

- File: `.kiro/agents/game-quality-agent.md`, committed with the rest of `.kiro/`.
- Created with Kiro's built-in `custom-agent-creator` agent, not written by hand. The format was checked against the IDE first: a Markdown file in `.kiro/agents/<id>.md` with YAML frontmatter.
- Frontmatter:

```yaml
name: game-quality-agent
description: Read-only quality reviewer for the HauntQuest AI Flutter game (Kiroween 2026, Costume Contest). ...
tools: ["read", "shell"]
includeMcpJson: false
includePowers: false
```

- Tool tags: `read` and `shell`, with no `write`. The agent reviews and reports but never edits, so running it cannot break the playable game. `includeMcpJson` and `includePowers` are false because neither is available (see sections 3 and 4).
- The body of the file is the agent's system prompt. It covers six review areas:
  1. puzzle solvability
  2. narrative progression
  3. accessibility
  4. Flutter architecture consistency
  5. test coverage gaps
  6. Costume Contest UI polish

  It also gives the commands to run and a severity-sorted report format (Critical, Major, Minor, Not verified, Commands run).

### How to run it

- In chat, ask Kiro to "run the game-quality-agent on areas 3 and 6" (or any subset). Kiro calls it as a sub-agent.
- From the Kiro agents panel, select `game-quality-agent`.
- Typical commands it runs (all read-only): `flutter analyze`, `flutter test test/content test/domain`, `flutter test test/ui`, `grep`, and `python3` one-liners that count content entries.

### Tasks performed and observed results

Run 1 covered areas 1 (solvability) and 4 (architecture).
- `flutter test test/content test/domain` gave 260 passed. `flutter analyze` reported no issues.
- All 16 puzzles in `assets/content/puzzles.json` have three hint tiers. The ending rules end with an `always` rule that leads to the release ending, so the game can always be finished.
- `lib/domain` and `lib/content` have no Flutter imports.
- Minor finding: empty or log-free `catch` blocks in `lib/app/audio/audio_director.dart`, `lib/app/game_store.dart`, `lib/app/settings_controller.dart` and `lib/app/persistence/atomic_preferences.dart`. This conflicts with the "No silent failures" rule in `quality.md`.
- Minor finding: steering drift. `product.md` says 9 puzzles (there are 16). `tech.md` lists `audioplayers` as planned, but it is already in `pubspec.yaml`.

Run 2 covered areas 3 (accessibility) and 6 (contest UI).
- `flutter test test/ui` gave 94 passed and 0 failed.
- Major: the Status and Known Gaps text in steering is stale (persistence, audio and puzzle count), while README matches the code.
- Major: the inventory drawer grip (`lib/features/inventory/inventory_drawer.dart`, `_DrawerGrip`) has a tap area of about 48x21 dp, below the 48 dp minimum. The UI guideline tests do not cover it.
- Minor: two dismiss `IconButton`s without a tooltip or label (`inventory_screen.dart`, `inventory_drawer.dart`).
- Minor: 12 raw `Color(0x...)` literals in `lib/features` instead of `AppColors` tokens.
- Minor: dialogue and intro text panels use `GestureDetector` without semantics. Someone needs to confirm that another accessible way to advance the text exists.
- Every `.repeat()` animation checks `MotionPolicy.reduceOf`.
- No player-facing text claims a feature that does not exist.

The findings are open and assigned to the owners of that code. The agent is read-only by design, so it did not fix them.

### Coverage baseline (measured alongside the agent)

`flutter test --coverage`: 368 tests passed, 93.2% line coverage (9384 of 10069 lines).

| Area | Line coverage |
|---|---|
| `lib/app` | 86.0% |
| `lib/content` | 92.1% |
| `lib/core` | 95.3% |
| `lib/domain` | 92.3% |
| `lib/features` | 93.6% |

Lowest files: `lib/app/audio/local_audio_backend.dart` (0%, platform audio backend), `manor_tokens.dart` (66.7%), `blocked_hints.dart` (73.7%), `app_services.dart` (74.3%).

To reproduce:

```
flutter test --coverage
# then read coverage/lcov.info (coverage/ is gitignored)
```

## 2. Skill: security-audit (a skill, not a Power)

Kiro skills are installed at the user level in `~/.kiro/skills/`. Three are available: `frontend-design`, `security-audit` and `web-design-guidelines`. They are not Kiro Powers and are not stored in this repository.

`security-audit` was activated in guidance mode. That means a focused review of named code, not the full multi-phase audit, and no report artifacts. `web-design-guidelines` was not used because it targets HTML and CSS interfaces, not Flutter widgets.

### Scope

- `tool/hooks/run.sh`, `tool/hooks/kiro_hook.dart`, `tool/hooks/checks.dart`: shell injection, argument handling, hook stdin parsing, path handling, and secret masking.
- The app: how credentials are handled, and whether any secrets are committed.

### Confirmed findings and fixes

1. **The `.gitignore` guard could be bypassed with a non-normalized path. Fixed.**
   - Boundary: the PreToolUse hook `protect-kiro-gitignore` compared the raw path with `.gitignore`.
   - Before the fix, `./.gitignore`, `<root>/./.gitignore` and `<root>/lib/../.gitignore` all exited 0. A write that adds `.kiro/` would have passed.
   - Fix: `relativeTo` in `checks.dart` now resolves `.`, `..` and repeated slashes before comparing.
2. **Nested ignore files could hide `.kiro` content without the guard noticing. Fixed.**
   - Boundary: writes to `.kiro/**/.gitignore` or `.git/info/exclude`, and commit or scan checks that only probed one file (`.kiro/steering/product.md`).
   - Fixes:
     - The pre-write guard now blocks any active rule in a `.gitignore` inside `.kiro/`, and treats `.git/info/exclude` like the root `.gitignore`.
     - The commit guard and `scan` now also run `git ls-files --others --ignored --exclude-standard -- .kiro`.
     - `run.sh` passes `info/exclude` events through its prefilter.

Verification:
- Probe results after the fix:
  - All 7 bypass variants exit 2 (blocked).
  - Harmless writes exit 0: `*.log` in the root, `*` in `android/.gitignore`, a comment in `.kiro/.gitignore`.
- A `/tmp` Git sandbox with `.kiro/hooks/.gitignore` set to `*.json` makes `scan` report `.kiro/hooks/a.json: is inside .kiro/ but ignored by Git` and exit 1. The sandbox was deleted afterwards.
- Unit tests were added to `test/tool/hook_checks_test.dart`. `flutter test test/tool` gives 16 passed, and `flutter analyze` is clean.

### Checked, no issue found

- Shell injection: `run.sh` quotes the hook input (`printf '%s' "$input"`) and never uses `eval`. Dart runs subprocesses with argument lists (`Process.run`, no shell on macOS or Linux).
- Argument injection into `dart format` and `dart analyze`: only paths under `lib/`, `test/`, `tool/` and `integration_test/` reach them, so a path cannot start with `-`.
- Secret output: matches are masked to 4 characters plus a length. The full value is never printed.
- Committed secrets: `sh tool/hooks/run.sh scan` scanned 293 files and found none. No `.env`, `local.properties`, `key.properties` or keystore is tracked.
- App credentials: `lib/` has no `String.fromEnvironment`, HTTP client, `Uri.parse` or API key code. No AI networking exists yet, so no credential is used at runtime.

### Needs validation (not confirmed)

- Hooks fail open. If `dart` is missing or the event JSON is malformed, they exit 0 or non-2, which does not block. This is a deliberate choice so the hooks never stop work, but it means they are guard rails, not a security boundary.
- The commit prefilter (`git[^"]*(commit|push)`) can miss unusual forms such as `git -c "k=v" commit`. `git -C dir commit` is detected, but the files are checked in the workspace root, not in `dir`.

## 3. MCP

What was checked:
- No `~/.kiro/settings/mcp.json`.
- No `.kiro/settings/` in the workspace.
- No MCP-related keys in the IDE user settings.

No MCP server is configured, so none was used. Adding one was not done. Every candidate would be a new, unreviewed server that runs code on the developer's machine, and the task rules out installing unreviewed servers or exposing credentials.

What it would improve, if a reviewed server were added later (not installed):
- A documentation server could answer Flutter and Dart API questions without web searches.
- A Git or GitHub server could create PRs from the agent.

Either one should go in `.kiro/settings/mcp.json` with `disabled: true` until it has been reviewed, and with no tokens in the file.

## 4. Kiro Powers

What was checked:
- The `kiro_powers list` action reports "No powers installed".
- `~/.kiro/powers/installed.json` has an empty `installedPowers`.
- The local registry lists 23 Powers, including postman, figma, netlify-deployment, supabase, strands, stripe, terraform, datadog, dynatrace, neon, cloud-architect, saas-builder, power-builder and several AWS ones. None of them is for Flutter, Dart, testing or security.

No Power was installed or invoked. The nearest equivalents are the custom agent (testing and quality) and the `security-audit` skill (security).

## 5. Verification steps

```
# Agent file is tracked, not ignored (prints nothing when tracked)
git check-ignore -v .kiro/agents/game-quality-agent.md

# Hook guards and their tests
flutter test test/tool
sh tool/hooks/run.sh scan

# Guard probe (should print "exit 2")
printf '{"tool_name":"fs_append","tool_input":{"path":"./.gitignore","text":".kiro/\\n"}}' \
  | sh tool/hooks/run.sh pre-write; echo "exit $?"

# Whole project
flutter analyze
flutter test
```

No screenshots are included. The custom agent's output is text, and the reports above are its findings in summary form.

## 6. Limitations

- **The agent is not truly read-only.** It is read-only by tool set and by its prompt. It has `shell`, so a shell command could still write files. The prompt forbids this, but the tool set does not prevent it.
- **The agent reports but does not fix.** Its findings need a separate change by whoever owns the code.
- **No MCP and no Powers** were available or used (sections 3 and 4).
- **Skills are user-level.** `security-audit` lives in `~/.kiro/skills/`, so another machine needs it installed to repeat the review.
- **Discovery timing.** Agents and hooks are normally loaded at session start. The new agent could be invoked in the same session, but hook changes take effect only in the next session.
- **Concurrent work.** A second session changed the game while this work happened (saves, audio, 16 puzzles). The test counts above are from October 31, 2026 and will change. The steering drift the agent found comes from that concurrent work.
- **Nothing was verified on a physical device or with a screen reader** as part of this work.
