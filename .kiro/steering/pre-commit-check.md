---
inclusion: manual
description: Pre-commit safety check and focused tests. Include with #pre-commit-check (or run as /pre-commit-check) before committing outside the agent.
---

# Pre-commit check (manual)

Kiro hooks cannot intercept commits made from a terminal or the Source Control view, and the agent hook tool does not support the `Manual` trigger. Use this checklist instead. Every command is read-only.

When this file is included, run these steps in order and report the results. Do not commit, push, stage, or edit files as part of this check.

1. Secret and `.gitignore` scan:
   `sh tool/hooks/run.sh scan`
   - Exit 0: no obvious secrets, build artifacts are ignored, `.kiro/` is tracked.
   - Exit 1: list every finding. Secrets are shown masked; never print a full secret value.
2. Focused game-logic tests (seconds, not the full suite):
   `sh tool/hooks/run.sh tests`
3. Analysis: `flutter analyze` must report no issues.

If a finding is a deliberate false positive (for example a documented test fixture), add the comment `kiro-allow-secret` on that line rather than weakening the scanner.
