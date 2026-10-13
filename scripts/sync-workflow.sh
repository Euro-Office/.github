#!/usr/bin/env bash
# Opens one PR per repo that adds or updates workflows from workflow-templates/.
# Without --template, every template is checked but only workflows a repo already has are updated.
# Without --repo, all org repos are checked.
# Usage: ./sync-workflow.sh [--template NAME] [--dry-run] [--repo OWNER/REPO]...
#   --template  Template name without extension, e.g. conventional-commits
#   --dry-run   Print planned changes without applying them
#   --repo      Target repo (repeatable); with --template, adds the workflow if missing

set -euo pipefail

ORG="Euro-Office"
TEMPLATE_DIR="$(dirname "$0")/../workflow-templates"
BRANCH="ci/sync-workflow-templates"
TITLE="ci: sync workflows from organization templates"

DRY_RUN=false
TEMPLATE=""
REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --template) TEMPLATE="$2"; shift ;;
    --repo) REPOS+=("$2"); shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ -n "$TEMPLATE" ]]; then
  [[ -f "$TEMPLATE_DIR/$TEMPLATE.yml" ]] || { echo "No such template: $TEMPLATE" >&2; exit 1; }
  TEMPLATES=("$TEMPLATE")
else
  TEMPLATES=()
  for f in "$TEMPLATE_DIR"/*.yml; do TEMPLATES+=("$(basename "$f" .yml)"); done
fi

ADD_MISSING=$([[ -n "$TEMPLATE" && ${#REPOS[@]} -gt 0 ]] && echo true || echo false)

log() { echo "[sync-workflow] $*"; }

sync_repo() {
  local repo="$1" default_branch current template target content
  local changed=() contents=() shas=()

  # set -e is ignored inside a function called with ||, so failures return explicitly
  default_branch=$(gh api "repos/$repo" --jq .default_branch) || return 1

  for template in "${TEMPLATES[@]}"; do
    target=".github/workflows/$template.yml"
    content=$(<"$TEMPLATE_DIR/$template.yml")
    content=${content//\$default-branch/$default_branch}

    if current=$(gh api "repos/$repo/contents/$target?ref=$default_branch" 2>/dev/null); then
      [[ "$(jq -r .content <<< "$current" | base64 -d)" == "$content" ]] && continue
      log "UPDATE $repo :: $target"
      shas+=("$(jq -r .sha <<< "$current")")
    elif [[ "$ADD_MISSING" == true ]]; then
      log "ADD    $repo :: $target"
      shas+=("")
    else
      continue
    fi
    changed+=("$template")
    contents+=("$content")
  done

  [[ ${#changed[@]} -eq 0 ]] && return 0

  [[ "$DRY_RUN" == true ]] && return 0

  local base_sha
  base_sha=$(gh api "repos/$repo/git/ref/heads/$default_branch" --jq .object.sha) || return 1
  # Force-reset instead of delete, so an already open sync PR stays open and gets refreshed
  gh api -X PATCH "repos/$repo/git/refs/heads/$BRANCH" -f sha="$base_sha" -F force=true >/dev/null 2>&1 \
    || gh api "repos/$repo/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$base_sha" >/dev/null \
    || return 1

  local body="Automated sync from https://github.com/$ORG/.github/tree/main/workflow-templates:"$'\n'
  for i in "${!changed[@]}"; do
    gh api -X PUT "repos/$repo/contents/.github/workflows/${changed[$i]}.yml" \
      -f message="ci: sync ${changed[$i]} workflow from organization template" \
      -f branch="$BRANCH" \
      -f content="$(base64 <<< "${contents[$i]}" | tr -d '\n')" \
      ${shas[$i]:+-f sha="${shas[$i]}"} >/dev/null || return 1
    body+=$'\n'"- \`.github/workflows/${changed[$i]}.yml\`"
  done

  if gh pr list --repo "$repo" --head "$BRANCH" --json number --jq '.[0].number' | grep -q .; then
    gh pr edit "$BRANCH" --repo "$repo" --body "$body" >/dev/null
    log "REFRESHED open PR in $repo"
  else
    gh pr create --repo "$repo" --base "$default_branch" --head "$BRANCH" --title "$TITLE" --body "$body"
  fi
}

if [[ ${#REPOS[@]} -eq 0 ]]; then
  while IFS= read -r repo; do REPOS+=("$repo"); done \
    < <(gh repo list "$ORG" --limit 200 --no-archived --source --json nameWithOwner --jq '.[].nameWithOwner')
fi

FAILED=0
for repo in "${REPOS[@]}"; do
  sync_repo "$repo" || { log "WARN: failed for $repo"; FAILED=1; }
done

log "Done."
exit "$FAILED"
