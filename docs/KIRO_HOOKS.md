# Kiro Workflow: Agent Hooks

How HauntQuest AI uses Kiro agent hooks, what each one does, how it was verified, and what native hooks cannot do.

## Kiro version and hook format

- **Kiro IDE 1.4.62** (installed IDE bundle metadata).
- Hooks use the **v2 format**: one JSON file per hook in `.kiro/hooks/<id>.json`. This build marks the older `.kiro.hook` format as deprecated ("Legacy hook (.kiro.hook format)"), so it is not used.
- All hook files were created with Kiro's own `createHook` tool, not written by hand.

The schema below was read from the installed IDE's validator (`kiro.kiro-agent/dist/extension.js`), not assumed:

```text
file    { version: "v1", hooks: Hook[] (at least 1) }
Hook    { name: string (required), description?: string, trigger: string,
          matcher?: regex string, action: Action, timeout?: int seconds (default 60),
          enabled?: boolean, confirm?: { question, options[{id,label,run,continueReason?}],
          confirmCommand? } }
Action  { type: "command", command: string } | { type: "agent", prompt: string }
trigger PostFileCreate | PostFileSave | PostFileDelete | PreToolUse | PostToolUse |
        UserPromptSubmit | SessionStart | Stop | PreTaskExec | PostTaskExec | Manual
```

How the runtime treats a command hook's result (from the same code):

| Trigger | Exit 0 | Exit 2 | Other exit |
|---|---|---|---|
| `PreToolUse` | allowed; stdout is parsed for a JSON `permissionDecision` (`ask` prompts the user) | **blocks the tool call**; stderr goes to the agent | allowed |
| `UserPromptSubmit`, `PreTaskExec` | stdout goes to the agent | blocks; stderr goes to the agent | allowed |
| `SessionStart` | stdout goes to the agent | not blocking | not blocking |
| `PostFileSave`, `PostToolUse`, others | output recorded in the IDE's hook activity, **not** sent to the agent | not blocking | not blocking |

Other facts from the runtime: the hook receives JSON on stdin (`session_id`, `hook_event_name`, `cwd`, plus `file_path` for file events or `tool_name`/`tool_input` for tool events); commands run with the workspace as the working directory; a `matcher` is a regex tested against the file path (file triggers) or the tool name (tool triggers).

## The hooks

All command hooks call `sh tool/hooks/run.sh <mode>`. That script rejects irrelevant events with a quick text test (about 20 ms) before starting `dart tool/hooks/kiro_hook.dart`, which holds the I/O. The pure check logic is in `tool/hooks/checks.dart` and is unit-tested in `test/tool/hook_checks_test.dart` (14 tests).

| # | Hook name (file) | Trigger | Action | Development benefit |
|---|---|---|---|---|
| 1 | **Dart format and targeted analysis on save** (`dart-post-save-check.json`) | `PostFileSave`, matcher `(\.dart\|(^\|/)\.gitignore\|assets/content/.*\.json)$` | Read-only `dart format --output=none --set-exit-if-changed <file>`. `dart analyze --fatal-infos <file>` only for `lib/domain`, `lib/content`, `lib/app`. Prints the focused test command after game-logic or content changes. For `.gitignore`: checks build artifacts are ignored and `.kiro/` is not. | Formatting and analyzer problems surface on the file you just saved, in about 1 to 3 s, with no full-project run. |
| 2 | **Dart checks after agent edits** (`dart-post-agent-edit-check.json`) | `PostToolUse`, matcher `^(fs_write\|str_replace\|fs_append)$` | Same checks as hook 1, for files the agent writes. | Agent edits get the same per-file checks as human edits. |
| 3 | **Keep .kiro tracked in Git** (`protect-kiro-gitignore.json`) | `PreToolUse`, matcher `^(fs_write\|str_replace\|fs_append)$` | If the write targets the root `.gitignore`, computes the resulting file. **Exit 2 blocks the write** if any rule (`.kiro`, `.kiro/*`, `**/.kiro`, `.*`, ...) would exclude `.kiro/` without a later `!.kiro/`. | The specs, steering and hooks that prove Kiro usage cannot be dropped from Git by an agent edit. |
| 4 | **Scan for secrets and artifacts before git commit** (`guard-git-commit.json`) | `PreToolUse`, matcher `^execute_bash$` | On `git commit` (also inside chains such as `git add . && git commit`): scans the files being committed (staged files, plus modified and untracked ones when the command stages them) for obvious secrets, build output, keystores, `.env`, `local.properties` and APKs, and asks Git whether `.kiro/` would be ignored. **Exit 2 blocks the commit** on findings, with secrets masked. On `git push`: returns `permissionDecision: "ask"` so the user must approve. | Stops accidental credential or artifact commits by the agent, and makes every push a deliberate user decision. |
| 5 | **Pre-commit check (manual)** (`.kiro/steering/pre-commit-check.md`, `inclusion: manual`) | Included by the user (`#pre-commit-check` or `/pre-commit-check`) | Runs `sh tool/hooks/run.sh scan` (secrets and `.gitignore` across the tracked and untracked files) and `sh tool/hooks/run.sh tests` (`flutter test test/domain test/content`), then `flutter analyze`. | Covers commits from a terminal or the Source Control view, which no hook can intercept. Gives engine and content tests on demand without running the whole suite. |

### Why these cannot loop or do damage

- **No hook writes a project file.** The format check uses `--output=none`; analysis and scans only read. So a check never causes the save or edit event that would re-trigger it. Verified: running the post-edit check twice on a file leaves its checksum unchanged.
- **Hooks do not call agent tools.** Hook commands are run by the hook runner, not through `execute_bash` or `fs_write`, so the `PreToolUse` and `PostToolUse` hooks cannot trigger each other or themselves.
- **No destructive or remote operations.** The scripts never stage, commit, push, reset, delete, or change Git configuration. The only Git commands are read-only: `rev-parse`, `diff --name-only`, `ls-files`, `check-ignore`.
- **Cheap when irrelevant.** Hooks 2, 3 and 4 fire on every matching tool call. The shell prefilter exits in about 20 ms unless the event mentions a `.dart` file, `.gitignore`, or `git commit/push`.
- **No full test runs.** Tests are only suggested, or run on demand via the manual check, and only the focused directories (about 7 s).

## Verification

Kiro reported, when each hook was created, that **v2 hooks become active at the next session start**. The hooks therefore could not fire live in the session that created them, and a controlled agent write in that session produced no hook output (as expected). Each hook's command was instead verified by feeding it the same JSON payload Kiro sends, taken from the runtime's own event builder:

| Hook | Controlled change | Expected | Result |
|---|---|---|---|
| 1 / 2 post-edit | Clean `lib/domain/engine/game_engine.dart` | format ok, analyze clean, suggests `flutter test test/domain`, exit 0 | **Pass** (1.2 s) |
| 1 / 2 post-edit | Probe file `void   main( ) {  }` | reports "needs formatting", exit 1, **file unchanged** (same checksum after two runs) | **Pass**, no loop |
| 1 / 2 post-edit | `README.md` saved | prefilter exits 0, nothing runs | **Pass** (0.02 s) |
| 3 pre-write | Agent appends `.kiro/` to `.gitignore` | blocked, exit 2, names the offending rule | **Pass** |
| 3 pre-write | Agent appends `*.log` | allowed, exit 0 | **Pass** |
| 4 pre-bash | `flutter analyze` | prefilter exits 0 | **Pass** (0.02 s) |
| 4 pre-bash | `git push -u origin feature` | `permissionDecision: "ask"` JSON, exit 0 | **Pass** |
| 4 pre-bash | `git commit` with nothing staged (this repository) | allowed, exit 0 | **Pass** (0.4 s) |
| 4 pre-bash | Throwaway repo in `/tmp`: staged fake AWS key | blocked, exit 2, key masked (`AKIA…****`), full key never printed | **Pass** |
| 4 pre-bash | Throwaway repo: `git add -A && git commit` with an unstaged secret and a force-added `build/app.apk` | blocked, exit 2, both reported | **Pass** |
| 4 pre-bash | Throwaway repo: `.kiro/` in `.git/info/exclude` | blocked, exit 2, Git's own rule shown | **Pass** |
| 5 manual | `sh tool/hooks/run.sh scan` on this repository | 291 files scanned, no findings, exit 0 | **Pass** (0.7 s) |
| 5 manual | `sh tool/hooks/run.sh tests` | focused engine and content tests pass | **Pass** (about 7 s) |

The throwaway repositories were created under `/tmp` and deleted afterwards. The project repository was never staged, committed or modified by these tests.

### Finish the live check after restarting Kiro

1. Start a new Kiro session (the hooks load at session start) and confirm the four hooks appear in the Agent Hooks panel.
2. Ask the agent to add a badly formatted line to a scratch Dart file under `tool/`. Hook 2 should show "needs formatting" in the hook activity, run once, and stop. Delete the scratch file.
3. Save `lib/domain/engine/game_engine.dart` in the editor. Hook 1 should show "format: ok / analyze: no issues" and the focused test suggestion.
4. Ask the agent to add `.kiro/` to `.gitignore`. Hook 3 should block the write.
5. Ask the agent to run `git push`. Kiro should ask for your approval.

## Limitations of native hooks (and the fallbacks used)

- **No Git pre-commit event.** Kiro hooks see the agent's tool calls, not Git. Hook 4 only guards commits the agent runs through `execute_bash`. Commits from a terminal or the Source Control view are not intercepted; use the manual pre-commit check (hook 5). A standard Git `pre-commit` hook calling `sh tool/hooks/run.sh scan` would close this gap, but it lives outside Kiro and was not installed automatically.
- **`Manual` trigger not available to the agent.** The IDE's v2 schema lists `Manual`, but `createHook` refuses it. Rather than hand-writing a hook file, the on-demand checks use a native `inclusion: manual` steering file, as the tool recommends.
- **Post-edit output is not fed to the agent.** For `PostFileSave` and `PostToolUse`, the runtime records a command's output in the hook activity but does not add it to the agent's context, and the exit code never blocks. These hooks therefore inform; they do not enforce. Enforcement lives in the `PreToolUse` hooks (exit 2) and the project rule in `.kiro/steering/quality.md` to run analysis and tests after major changes.
- **`timeout` placement.** `createHook` writes `timeout` inside `action`, but the IDE reads it from the hook level and silently drops the nested key. Every hook therefore runs with the default **60 s** limit. All checks finish in 0.02 to 3 s, so this is harmless; it is recorded here so nobody relies on the nested value.
- **Path filtering on tool hooks.** Tool-trigger matchers match tool names, not paths, so hooks 2 and 3 run for every write and filter by path inside the script (the 20 ms prefilter keeps this cheap).
- **Secret detection is heuristic.** It catches obvious accidents (private keys; AWS, GitHub, Google, Slack, Stripe, OpenAI and Anthropic key shapes; quoted credentials of 16 or more characters). It is not a replacement for a dedicated scanner. Deliberate fixtures can be marked with `kiro-allow-secret` on the line.

## Files

- `.kiro/hooks/*.json`: the four v2 hooks.
- `.kiro/steering/pre-commit-check.md`: manual pre-commit checklist.
- `tool/hooks/run.sh`: prefilter and entry point.
- `tool/hooks/kiro_hook.dart`: read-only checks with I/O.
- `tool/hooks/checks.dart`: pure check logic.
- `test/tool/hook_checks_test.dart`: unit tests for the check logic.
