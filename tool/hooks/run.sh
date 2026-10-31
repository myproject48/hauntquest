#!/bin/sh
# Fast front door for the Kiro hooks in .kiro/hooks/.
#
# PreToolUse/PostToolUse hooks fire on every matching tool call, so this
# script rejects irrelevant events with a cheap text test before starting the
# Dart VM. It is read-only and never runs git commit, git push, or any
# command that changes files.
#
# Usage: sh tool/hooks/run.sh <post-edit|pre-write|pre-bash|scan|tests>
set -u
mode="${1:-}"
cd "$(dirname "$0")/../.." || exit 0

DART="$(command -v dart 2>/dev/null)"
if [ -z "$DART" ] && command -v flutter >/dev/null 2>&1; then
  DART="$(dirname "$(command -v flutter)")/dart"
fi
if [ -z "$DART" ] || [ ! -x "$DART" ]; then
  echo "kiro hook: dart not found on PATH; skipping $mode check." >&2
  exit 0
fi

case "$mode" in
  scan)
    exec "$DART" tool/hooks/kiro_hook.dart scan ;;
  tests)
    # Focused game-logic tests only (seconds, not the whole suite).
    FLUTTER="$(command -v flutter 2>/dev/null || echo "$(dirname "$DART")/flutter")"
    exec "$FLUTTER" test test/domain test/content ;;
esac

input="$(cat)"
case "$mode" in
  post-edit)
    printf '%s' "$input" | grep -Eq '\.(dart|gitignore|json)"' || exit 0 ;;
  pre-write)
    printf '%s' "$input" | grep -Eq '\.gitignore|info/exclude' || exit 0 ;;
  pre-bash)
    printf '%s' "$input" | grep -Eq 'git[^"]*(commit|push)' || exit 0 ;;
  *)
    echo "usage: sh tool/hooks/run.sh post-edit|pre-write|pre-bash|scan|tests" >&2
    exit 0 ;;
esac

printf '%s' "$input" | exec "$DART" tool/hooks/kiro_hook.dart "$mode"
