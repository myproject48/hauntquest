# How Kiro contributed to HauntQuest AI

## Submission write-up

Kiro was used as a development environment and workflow tool for the Flutter game.
The repository retains its specification, steering, real hook configurations and
a custom quality-agent configuration so reviewers can inspect concrete artifacts.
This is development-time assistance; the installed game does not call Kiro or a
live AI model.

The original specification separates requirements, design and implementation tasks
under `.kiro/specs/hauntquest-ai-game/`. It breaks investigation into rooms, clues,
puzzle validation, inventory, dialogue, persistence, accessibility and release
checks. That separation supports a pure-Dart game engine and data-driven content
that can be exercised independently of Flutter presentation. The release expanded
from the initial nine-puzzle plan to sixteen puzzles and updated the ending design;
the historical plan remains alongside an explicit release note.

Steering documents define constraints that matter to this project: original art
and writing, offline play, untimed tap controls, consistent design tokens, rules
outside widgets and truthful feature descriptions. These focused constraints give
agent edits and reviews a shared standard instead of an open-ended request to
“make a spooky game.” No measured productivity comparison with another workflow
is claimed.

Four actual hook configurations support local checks. Post-save and post-agent-edit
hooks run read-only formatting/targeted-analysis checks. A pre-write guard protects
`.kiro` from ignore rules, and a Git-command guard checks obvious secrets/artifacts
before agent commits and asks before pushes. Their shell/Dart implementation and
tests are included. They do not rewrite source or intercept every terminal action;
the manual pre-commit steering checklist covers work outside the agent workflow.

The retained `game-quality-agent` configuration organizes reviews of solvability,
architecture, accessibility, test coverage and visual consistency. The historical
workflow record describes its invocations and findings. This package does not
claim a fresh agent run, an always-enforced read-only sandbox or unrecorded bug fixes.

The project also includes exhaustive puzzle checks where useful, seeded randomized
state-transition tests and narrative branch traversal. These support the spec's
requirements around reachability, valid state, nonduplicated rewards and saves.
They complement individual correct/incorrect-answer tests. No claim is made that
a specific new bug was discovered by property testing without supporting evidence.

The recorded Kiro workflow used the IDE. No Kiro CLI/Web/Crew comparison, configured
MCP server or installed Kiro Power is claimed. User-level skills mentioned in the
historical record are not bundled project dependencies. This narrower description
keeps the submission consistent with the evidence available to judges.

## Evidence map for judges

| Contribution | Repository evidence |
| --- | --- |
| Requirements and planning | [requirements](../../.kiro/specs/hauntquest-ai-game/requirements.md), [design](../../.kiro/specs/hauntquest-ai-game/design.md), [tasks](../../.kiro/specs/hauntquest-ai-game/tasks.md) |
| Product and implementation constraints | [product](../../.kiro/steering/product.md), [technology](../../.kiro/steering/tech.md), [quality](../../.kiro/steering/quality.md), [game design](../../.kiro/steering/game-design.md) |
| Actual hooks | [hook configurations](../../.kiro/hooks/), [runner](../../tool/hooks/run.sh), [checks](../../tool/hooks/checks.dart) |
| Custom quality agent | [game-quality-agent.md](../../.kiro/agents/game-quality-agent.md) |
| Automated guard coverage | [hook_checks_test.dart](../../test/tool/hook_checks_test.dart) |
| Randomized state and branch coverage | [release invariants](../../test/domain/release_invariants_test.dart), [puzzle system tests](../../test/domain/complete_puzzle_system_test.dart) |
| Recorded workflow and limits | [Kiro workflow](../KIRO_WORKFLOW.md), [detailed hooks record](../KIRO_HOOKS.md), [historical agent record](../KIRO_ADVANCED_FEATURES.md) |
| Current release check results | [release validation](../RELEASE_VALIDATION.md) |

## Recording the evidence honestly

Open the actual project in Kiro and capture the files named above. Run checks in
its terminal and record their real outputs. If showing a native hook firing,
first confirm that the current IDE session has loaded it and capture its actual
activity result. Otherwise show the configuration and manual check only, labeled
as such. Do not manufacture a chat exchange, hook notification, screenshot or test
result. The screenplay uses configuration inspection plus real terminal output,
which does not require claiming a new live hook activation.
