# Submission claims and evidence

Prepared November 1, 2026. This is an editorial evidence map, not a new test report.
The release checks cited below were run in the preceding release-preparation pass.
This documentation pass rechecked the local APK hash and source/document integrity.

## Verified release facts

| Claim permitted in the submission | Evidence | Boundary |
| --- | --- | --- |
| Five rooms and sixteen playable puzzles | Local room/puzzle JSON; Flutter puzzle controls; [puzzle system tests](../../test/domain/complete_puzzle_system_test.dart), [UI tests](../../test/ui/complete_puzzles_ui_test.dart) | Do not imply all sixteen were shown in the native end-to-end recording |
| Three attainable endings | Declarative narrative data; [narrative tests](../../test/domain/narrative_system_test.dart), [branch invariants](../../test/domain/release_invariants_test.dart) | All three verified by automated logic/UI coverage, not three new native-device video recordings |
| Complete normal-input Android journey | [Native full-game test](../../integration_test/hall_and_library_test.dart); recorded passing run | Five rooms to Release the Echo, debug-mode instrumentation on an emulator |
| 394 passing tests; clean analysis | [November 1 release validation](../RELEASE_VALIDATION.md) and retained command results from that pass | Dated result, not a fabricated hosted CI run or current hardware benchmark |
| Save restoration | [Native reload test](../../integration_test/restart_restore_test.dart), save/UI tests | Platform preferences reloaded within the same process; manual cold force-stop remains additional verification |
| Original code-drawn art and local synthesized audio | [Asset provenance](../LICENSES_AND_ASSETS.md), painters and generators in source | No stock/model-generated artwork or sampled music/recordings claimed |
| Rule-based contextual companion | OfflineGuide, GuideService and Guide panel; [guide tests](../../test/domain/whispering_guide_test.dart) | No remote provider, model conversation or AI-generated prose enabled |
| Real Kiro project artifacts | Root `.kiro` specs/steering/hooks/agent; [workflow record](../KIRO_WORKFLOW.md) | Historical reported usage is attributed; no invented telemetry or fresh agent/hook invocation |
| Android release APK and Web release build | [Release report](../RELEASE_VALIDATION.md); local outputs | Development-signed evaluation APK; no Play Store release or hosted website implied |

The APK was rehashed for this package and matches the release report:

```text
4702ad331bd5e29a2dbf4eb71b34e3b37f03fd9e0ad373438322a10cfb7ddf1f
```

## Claims intentionally excluded

- “AI-powered gameplay,” live AI chat, generated dialogue, model-based puzzle
  validation or API-driven endings. The title **HauntQuest AI** is a project name;
  the installed Guide remains offline and rule-based.
- A published final repository, hosted APK, live site, recorded/uploaded demo or
  submitted Devpost form. Their real links remain pending.
- Measured player adoption, retention, completion times, productivity gains,
  award eligibility, contest acceptance, guaranteed FPS or physical-device certification.
- Newly measured coverage percentages. Historical coverage figures elsewhere in
  the repository are not promoted as fresh submission metrics.
- Cloud/manual save slots, localization beyond English, store distribution,
  MCP/Kiro Power usage, or native validation on every scaffolded platform.

## Refresh before publication

If gameplay code, dependencies, content, signing, assets or the distributed binary
change, rerun the relevant checks, update the release report/hash, and revise the
copy/video captions. Do not preserve a success count merely because it appears in
a draft. Retain full terminal/source footage for any test result shown in the video.

Review all personal/team statements with the entrant. The copy describes the
project's design and implementation without inventing personal background stories.
