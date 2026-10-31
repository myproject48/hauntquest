# Kiro development workflow

HauntQuest AI was developed for Kiroween 2026's **Costume Contest**, using Kiro
specification, steering and agent workflows. This document identifies repository
evidence and separates implemented automation from plans and historical reports.
It does not claim that Kiro runs inside the installed game.

## Specification-driven foundation

The original requirements, design and task plan are retained under
[`.kiro/specs/hauntquest-ai-game/`](../.kiro/specs/hauntquest-ai-game/).
They specify the five-room investigation, deterministic engine, inventory,
puzzles, narrative decisions, accessibility, persistence and optional assistance.
Breaking the game into content, rules and presentation made individual systems
independently testable and enabled complete legal playthrough fixtures.

The initial plan targeted nine puzzles and earlier ending names. The implemented
release has sixteen puzzles, seven dialogue nodes and Release/Seal/Guardian
endings. These scope changes are documented in the release note in the spec,
[README](../README.md) and [architecture](ARCHITECTURE.md); unchecked historical
tasks are not evidence that a current implementation is absent.

## Steering

[`.kiro/steering/`](../.kiro/steering/) retains product, technology, structure,
game-design, quality and manual pre-commit guidance. They establish original art
and writing, offline-first behavior, tap-only untimed puzzles, design tokens,
separation of pure-Dart rules from Flutter presentation, and honest feature claims.
These concrete constraints focus agent edits and reviews on the game's actual
requirements rather than generic UI scaffolding.

## Actual hooks and local tooling

Four hook configurations are retained in [`.kiro/hooks/`](../.kiro/hooks/):

| Hook | Contribution |
| --- | --- |
| Dart post-save check | Read-only formatting and targeted analysis, with focused-test suggestions |
| Dart post-agent-edit check | Applies the same checks to agent-written Dart files |
| Protect Kiro Git ignore | Rejects agent changes that would hide submission evidence |
| Guard Git commit | Heuristic secret/artifact checks before agent commits; asks on pushes |

They call `tool/hooks/run.sh` and its Dart implementation. Hooks never rewrite
source, so their checks cannot trigger save/edit loops. The manual steering
check covers terminal commits that IDE hooks cannot intercept. Guard behavior is
unit-tested in `test/tool/hook_checks_test.dart`. Hooks are guard rails, not a
complete security boundary; a successful heuristic scan is not proof that a
credential has never existed in history.

[KIRO_HOOKS.md](KIRO_HOOKS.md) retains the detailed recorded setup, payload probes,
version-specific behavior and limitations. Those October 31 development observations
are historical, not a claim that hooks were reactivated in this release session.

## Custom agent and review

[`.kiro/agents/game-quality-agent.md`](../.kiro/agents/game-quality-agent.md) is the
actual quality-review agent configuration. It asks for solvability, architecture,
accessibility, test-coverage and visual-consistency reviews and forbids edits.
Its shell capability means read-only behavior is a workflow rule, not a sandbox.
The recorded reviews and their findings are in
[KIRO_ADVANCED_FEATURES.md](KIRO_ADVANCED_FEATURES.md). Historical findings and test
counts are dated there; current validation results are in
[RELEASE_VALIDATION.md](RELEASE_VALIDATION.md).

## Testing and iteration

The spec's invariant goals are exercised by content graph validation, exhaustive
solution checks where applicable, seeded randomized legal/invalid actions,
strict save-codec round trips and narrative branch traversal. Native integration
tests also drive a complete five-room journey and reload device preferences.
These are concrete tests in `test/` and `integration_test/`; they do not rely on
Kiro being installed on a judge's machine. Claims that a particular tool found a
bug are limited to the recorded review evidence, rather than inferred from a
passing test suite.

## What is not claimed

- No configured MCP server or Kiro Power was used, according to the retained
  workflow record. User-level skills referenced there are not bundled project code.
- The release preparation does not invent editor telemetry, prompt histories,
  screenshots, usage metrics or a Kiro-only authorship claim for every source line.
- Runtime AI is not enabled. The Whispering Guide uses authored local rules;
  its optional provider interface cannot change authoritative game state.
- Source publication, video approval/upload and Devpost submission remain owner actions.

## Reproduce checks

```sh
flutter analyze
flutter test
sh tool/hooks/run.sh scan
python3 tool/check_release.py
```

Open this project root in Kiro to discover the retained specs/steering/agents.
Hook schema support varies by IDE version; the recorded setup used Kiro 1.4.62,
and new hook discovery required a new session. Do not remove `.kiro/` to publish.
