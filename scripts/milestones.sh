#!/usr/bin/env bash
# Manage milestones across the Euro-Office product repos.
# Usage:
#   ./milestones.sh [--repo OWNER/REPO] list [--all]
#   ./milestones.sh [--repo OWNER/REPO] create TITLE [--due YYYY-MM-DD] [--description TEXT]
#   ./milestones.sh [--repo OWNER/REPO] close TITLE
#   ./milestones.sh [--repo OWNER/REPO] move FROM TO [--dry-run]
#     Moves all open issues and PRs from milestone FROM to milestone TO.
#   ./milestones.sh scan TITLE --from REF [--to REF] [--dry-run]
#     Assigns milestone TITLE to all PRs merged between two DocumentServer refs,
#     in DocumentServer and every submodule it pins. Without --to, DocumentServer
#     is scanned up to main and each submodule up to the tip of its tracked branch.
#     PRs that already have a different milestone are reported, not changed.
# Without --repo every repo in REPOS is processed.

set -euo pipefail

export GH_PAGER=cat

ORG="Euro-Office"
SUPERPROJECT="$ORG/DocumentServer"

REPOS=(
  DocumentServer
  core
  sdkjs
  sdkjs-forms
  web-apps
  server
  build_tools
  document-server-package
  Docker-DocumentServer
  document-templates
  document-formats
  dictionaries
  core-fonts
  plugins
  eurooffice-nextcloud
  desktop-apps
  desktop-sdk
  DesktopEditors
)

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
log() { echo "[milestones] $*"; }

milestone_number() {
  gh api "repos/$1/milestones?state=all&per_page=100" --paginate \
    | jq -r --arg t "$2" '.[] | select(.title == $t) | .number'
}

cmd_list() {
  local repo="$1" state=open
  [[ "${2:-}" == "--all" ]] && state=all
  gh api "repos/$repo/milestones?state=$state&per_page=100" --paginate \
    --jq '.[] | [.title, .state, "open=\(.open_issues)", "closed=\(.closed_issues)", (.due_on // "-")[:10]] | @tsv' \
    | column -t -s $'\t'
}

cmd_create() {
  local repo="$1" title="${2:-}"; [[ -n "$title" ]] || usage; shift 2
  local args=(-f "title=$title")
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --due) args+=(-f "due_on=${2}T00:00:00Z"); shift ;;
      --description) args+=(-f "description=$2"); shift ;;
      *) usage ;;
    esac
    shift
  done
  if [[ -n "$(milestone_number "$repo" "$title")" ]]; then
    log "'$title' already exists, skipping"
    return
  fi
  gh api "repos/$repo/milestones" "${args[@]}" --jq '"Created \(.title): \(.html_url)"'
}

cmd_close() {
  local repo="$1" title="${2:-}"; [[ -n "$title" ]] || usage
  local number open
  number=$(milestone_number "$repo" "$title")
  [[ -n "$number" ]] || { log "'$title' not found, skipping"; return; }
  open=$(gh api "repos/$repo/milestones/$number" --jq .open_issues)
  [[ "$open" -eq 0 ]] || log "WARN: '$title' still has $open open issues/PRs, consider 'move' first"
  gh api -X PATCH "repos/$repo/milestones/$number" -f state=closed --jq '"Closed \(.title)"'
}

cmd_move() {
  local repo="$1" from="${2:-}" to="${3:-}" dry_run=false
  [[ -n "$from" && -n "$to" ]] || usage
  [[ "${4:-}" == "--dry-run" ]] && dry_run=true
  local from_number to_number
  from_number=$(milestone_number "$repo" "$from")
  [[ -n "$from_number" ]] || { log "'$from' not found, skipping"; return; }

  local items
  items=$(gh api "repos/$repo/issues?milestone=$from_number&state=open&per_page=100" --paginate \
    --jq '.[] | [.number, (if .pull_request then "PR" else "issue" end), .title] | @tsv')
  [[ -n "$items" ]] || { log "No open issues/PRs in '$from'"; return; }

  to_number=$(milestone_number "$repo" "$to")
  [[ -n "$to_number" ]] || { log "WARN: '$to' not found, create it first. Skipping"; return; }

  while IFS=$'\t' read -r number kind title; do
    if [[ "$dry_run" == true ]]; then
      log "[dry-run] would move $kind #$number $title"
    else
      if gh api -X PATCH "repos/$repo/issues/$number" -F "milestone=$to_number" --silent; then
        log "Moved $kind #$number $title"
      else
        log "WARN: failed to move $kind #$number"
      fi
    fi
  done <<< "$items"
}

submodule_shas() {
  gh api "repos/$SUPERPROJECT/git/trees/$1" --jq '.tree[] | select(.type == "commit") | "\(.path) \(.sha)"'
}

submodule_tips() {
  local gitmodules path sha branch
  gitmodules=$(gh api "repos/$SUPERPROJECT/contents/.gitmodules?ref=main" --jq .content | base64 -d)
  while read -r path sha; do
    branch=$(git config --file - --get "submodule.$path.branch" <<< "$gitmodules" || echo HEAD)
    echo "$path $(gh api "repos/$ORG/$path/commits/$branch" --jq .sha)"
  done < <(submodule_shas main)
}

scan_repo() {
  local repo="$1" base="$2" head="$3" title="$4" dry_run="$5"
  log "--- $repo ${base:0:7}..${head:0:7} ---"

  local milestone
  milestone=$(milestone_number "$repo" "$title")
  [[ -n "$milestone" ]] || { log "WARN: '$title' not found, create it first. Skipping"; return; }

  local commits
  commits=$(gh api "repos/$repo/compare/$base...$head?per_page=100" --paginate --jq '.commits[].sha')

  local number current pr_title
  while IFS=$'\t' read -r number current pr_title; do
    if [[ "$current" == "$title" ]]; then
      continue
    elif [[ "$current" != "-" ]]; then
      log "SKIP PR #$number has milestone '$current': $pr_title"
    elif [[ "$dry_run" == true ]]; then
      log "[dry-run] would assign PR #$number $pr_title"
    elif gh api -X PATCH "repos/$repo/issues/$number" -F "milestone=$milestone" --silent; then
      log "Assigned PR #$number $pr_title"
    else
      log "WARN: failed to assign PR #$number"
    fi
  done < <(gh api "repos/$repo/pulls?state=closed&per_page=100" --paginate \
    --jq '.[] | select(.merged_at) | [.merge_commit_sha, .number, (.milestone.title // "-"), .title] | @tsv' \
    | awk -F'\t' -v OFS='\t' 'NR == FNR { in_range[$1]; next } $1 in in_range { print $2, $3, $4 }' \
      <(echo "$commits") -)
}

cmd_scan() {
  local title="${1:-}" from="" to="" dry_run=false
  [[ -n "$title" ]] || usage; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from="$2"; shift ;;
      --to) to="$2"; shift ;;
      --dry-run) dry_run=true ;;
      *) usage ;;
    esac
    shift
  done
  [[ -n "$from" ]] || usage

  scan_repo "$SUPERPROJECT" "$from" "${to:-main}" "$title" "$dry_run" || log "WARN: scan failed for $SUPERPROJECT"

  local path base head
  while read -r path base head; do
    if [[ -z "$base" ]]; then
      log "WARN: $path is not pinned at $from, skipping"
    elif [[ "$base" != "$head" ]]; then
      # ponytail: assumes submodule path == repo name in $ORG, true for every DocumentServer submodule today
      scan_repo "$ORG/$path" "$base" "$head" "$title" "$dry_run" || log "WARN: scan failed for $ORG/$path"
    fi
  done < <(awk 'NR == FNR { base[$1] = $2; next } { print $1, base[$1], $2 }' \
    <(submodule_shas "$from") <(if [[ -n "$to" ]]; then submodule_shas "$to"; else submodule_tips; fi))
}

if [[ "${1:-}" == "scan" ]]; then
  shift
  cmd_scan "$@"
  exit
fi

targets=("${REPOS[@]/#/$ORG/}")
[[ "${1:-}" == "--repo" ]] && { targets=("$2"); shift 2; }
command="${1:-}"; shift || true
case "$command" in
  list|create|close|move) ;;
  *) usage ;;
esac

for repo in "${targets[@]}"; do
  log "--- $repo ---"
  "cmd_$command" "$repo" "$@" || log "WARN: '$command' failed for $repo"
done
