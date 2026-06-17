#!/usr/bin/env bash
# Syncs the canonical label set to every repo in the Euro-Office org.
# Labels are created if missing; color is updated if the name matches but color differs.
# Usage: ./sync-labels.sh [--dry-run] [--repo OWNER/REPO]
#   --dry-run   Print planned changes without applying them
#   --repo      Target a single repo instead of the whole org

set -euo pipefail

ORG="Euro-Office"

# ---------------------------------------------------------------------------
# Canonical label set — baseline from Euro-Office/DocumentServer
# Format: "name|rrggbb|description"  (color without leading #)
# ---------------------------------------------------------------------------
LABELS=(
  "bug|d73a4a|Something isn't working"
  "build|336904|Build process related changes"
  "chore|4C215D|"
  "containers|1376bd|"
  "dependencies|330CF0|"
  "design|5319e7|"
  "discussion|cc41b5|"
  "docker|aaaaaa|"
  "documentation|0075ca|Improvements or additions to documentation"
  "duplicate|cfd3d7|This issue or pull request already exists"
  "enhancement|a2eeef|New feature or request"
  "epic|9f615a|"
  "format: odf|aaaaaa|"
  "format: ooxml|aaaaaa|"
  "good first issue|7057ff|Good for newcomers"
  "help wanted|008672|Extra attention is needed"
  "invalid|e4e669|This doesn't seem right"
  "nc-report|cccccc|Nextcloud testing reports"
  "needs info|aaaaaa|"
  "organizational|aaaaaa|"
  "overview|000815|"
  "packages|1376bd|"
  "question|d876e3|Further information is requested"
  "side task|aaaaaa|"
  "tests|afeab5|"
  "wontfix|ffffff|This will not be worked on"
)

DRY_RUN=false
TARGET_REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --repo) TARGET_REPO="$2"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

log() { echo "[sync-labels] $*"; }
dry() { echo "[dry-run]     $*"; }

sync_repo() {
  local repo="$1"
  log "--- $repo ---"

  local existing_json
  existing_json=$(gh label list --repo "$repo" --limit 200 --json name,color 2>&1) || {
    log "WARN: could not list labels for $repo (skipping): $existing_json"
    return
  }

  for entry in "${LABELS[@]}"; do
    IFS='|' read -r name color description <<< "$entry"

    # Look up whether this label name exists and what color it has
    local current_color
    current_color=$(echo "$existing_json" | jq -r --arg n "$name" \
      '.[] | select(.name == $n) | .color' 2>/dev/null || true)

    if [[ -n "$current_color" ]]; then
      if [[ "$(echo "$current_color" | tr '[:upper:]' '[:lower:]')" != "$(echo "$color" | tr '[:upper:]' '[:lower:]')" ]]; then
        log "UPDATE $repo :: '$name'  $current_color -> $color"
        if [[ "$DRY_RUN" == false ]]; then
          gh label edit "$name" --repo "$repo" --color "$color" || \
            log "WARN: failed to update '$name' on $repo"
        else
          dry "gh label edit '$name' --repo '$repo' --color '$color'"
        fi
      fi
    else
      log "CREATE $repo :: '$name'  #$color"
      if [[ "$DRY_RUN" == false ]]; then
        gh label create "$name" --repo "$repo" --color "$color" --description "$description" || \
          log "WARN: failed to create '$name' on $repo"
      else
        dry "gh label create '$name' --repo '$repo' --color '$color' --description '$description'"
      fi
    fi
  done
}

if [[ -n "$TARGET_REPO" ]]; then
  sync_repo "$TARGET_REPO"
else
  while IFS= read -r repo; do
    sync_repo "$repo"
  done < <(gh repo list "$ORG" --limit 200 --json nameWithOwner --jq '.[].nameWithOwner')
fi

log "Done."
