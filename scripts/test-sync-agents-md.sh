#!/usr/bin/env bash
# Checks the AGENTS.md rendering of sync-agents-md.sh. Usage: ./test-sync-agents-md.sh
set -euo pipefail

SYNC="$(dirname "$0")/sync-agents-md.sh"
render() { "$SYNC" --render "$@"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
count() { grep -c -- "$1" <<< "$2" || true; }

# Missing block: untouched without --add, appended with it
plain=$'# Repo\n\nSome rules.'
[[ "$(render <<< "$plain")" == "$plain" ]] || fail "file without block was changed"
added=$(render --add <<< "$plain")
[[ "$added" == "$plain"$'\n\n<!-- euro-office-policy:start'* ]] || fail "block not appended after a blank line"
[[ "$added" == *'<!-- euro-office-policy:end -->' ]] || fail "end marker missing"
[[ $(count SPDX "$added") == 0 ]] || fail "SPDX header copied into block"

# Synced file is stable and keeps surrounding content
[[ "$(render <<< "$added")" == "$added" ]] || fail "second sync changed the file"
around="$added"$'\n\n## Local\n\nKeep me.'
stale=${around/Label every issue/Stale rule}
[[ "$(render <<< "$stale")" == "$around" ]] || fail "stale block not replaced or local content lost"
[[ $(count 'euro-office-policy:start' "$(render --add <<< "$around")") == 1 ]] || fail "--add duplicated an existing block"

# CRLF file keeps local content, normalised to LF
[[ "$(render <<< "$(sed 's/$/\r/' <<< "$around")")" == "$around" ]] || fail "CRLF file lost content"

# Duplicate blocks collapse into one
[[ $(count 'euro-office-policy:start' "$(render <<< "$added"$'\n'"$around")") == 1 ]] || fail "duplicate blocks not collapsed"

# Start without end marker fails instead of dropping the rest of the file
if render <<< $'# R\n<!-- euro-office-policy:start x -->\nold\n## Local' > /dev/null 2>&1; then
  fail "missing end marker not rejected"
fi

echo "OK"
