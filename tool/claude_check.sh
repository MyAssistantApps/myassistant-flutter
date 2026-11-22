#!/usr/bin/env bash
# CLAUDE CODE STOP CHECK (owner, 2026-11-22). Runs when a Claude Code
# session in this repo is about to say "done" (.claude/settings.json, Stop
# hook). If Dart files changed, it runs `flutter analyze` on them and the
# architecture guard test; on failure Claude is told what broke and keeps
# working until it passes. Unchanged files since the last pass: skipped.
set -u
input=$(cat)
# Already continuing because of this hook: let it stop (no endless loop).
echo "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 0
command -v flutter >/dev/null 2>&1 || exit 0

base=$(git merge-base HEAD origin/production 2>/dev/null || echo HEAD)
files=$( { git diff --name-only --diff-filter=ACMR "$base"; git ls-files --others --exclude-standard; } \
  | grep -E '^(lib|test)/.*\.dart$' | sort -u | while read -r f; do [ -f "$f" ] && echo "$f"; done)
[ -z "$files" ] && exit 0

stamp=.dart_tool/claude_check.sha
sum=$(cat $files | git hash-object --stdin)
[ -f "$stamp" ] && [ "$(cat "$stamp")" = "$sum" ] && exit 0

out=$(flutter analyze --no-pub $files 2>&1)
if echo "$out" | grep -qE '^\s*(error|warning) '; then
  { echo "flutter analyze found problems in the files you changed. Fix them before finishing:"
    echo "$out" | grep -E '^\s*(error|warning) ' | head -40; } >&2
  exit 2
fi
out=$(flutter test --no-pub test/architecture_guard_test.dart 2>&1)
if ! echo "$out" | grep -q 'All tests passed'; then
  { echo "The architecture rules in CLAUDE.md are broken (test/architecture_guard_test.dart)."
    echo "Follow the rule; do not edit the test to make it pass:"
    echo "$out" | grep -vE '^\s*$' | tail -30; } >&2
  exit 2
fi
mkdir -p .dart_tool && echo "$sum" > "$stamp"
exit 0
