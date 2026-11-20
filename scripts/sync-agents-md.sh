#!/usr/bin/env bash
# Opens one PR per repo that syncs the policy block in AGENTS.md from AGENT_MD_SNIPPETS.md.
# The block sits between euro-office-policy markers. Repos without them only get the block with --repo,
# appended at the end: move an older hand-written policy section into the markers first.
# Without --repo, all org repos are checked, except security advisory forks and rehearsal repos.
# Usage: ./sync-agents-md.sh [--dry-run] [--repo OWNER/REPO]...
#        ./sync-agents-md.sh --render [--add] < AGENTS.md   Print the synced file, for tests

set -euo pipefail

ORG="Euro-Office"
SNIPPET="$(dirname "$0")/../AGENT_MD_SNIPPETS.md"
TARGET="AGENTS.md"
BRANCH="docs/sync-agents-md"
TITLE="docs: sync AGENTS.md contribution policy from organization snippet"
START="<!-- euro-office-policy:start, synced from https://github.com/$ORG/.github/blob/main/AGENT_MD_SNIPPETS.md, edit it there -->"
END="<!-- euro-office-policy:end -->"

DRY_RUN=false
RENDER=false
ADD=false
REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --render) RENDER=true ;;
    --add) ADD=true ;;
    --repo) REPOS+=("$2"); shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

BLOCK_FILE=$(mktemp)
trap 'rm -f "$BLOCK_FILE"' EXIT
{
  echo "$START"
  # Drop the SPDX comment and the blank lines after it
  awk 'past && (seen || NF) { seen = 1; print } /^-->$/ { past = 1 }' "$SNIPPET"
  echo "$END"
} > "$BLOCK_FILE"

# Reads AGENTS.md on stdin, prints it with the block replaced, or appended when add=1
render() {
  awk -v blockfile="$BLOCK_FILE" -v add="$1" '
    function emit(  l) { while ((getline l < blockfile) > 0) print l; close(blockfile); done = 1 }
    { sub(/\r$/, "") }
    /^<!-- euro-office-policy:start/ { marked = 1; if (!done) emit(); next }
    /^<!-- euro-office-policy:end -->[ \t]*$/ { marked = 0; next }
    marked { next }
    { print }
    END {
      if (marked) { print "Start marker without end marker" > "/dev/stderr"; exit 2 }
      if (!done && add) { if (NR) print ""; emit() }
    }
  '
}

if [[ "$RENDER" == true ]]; then
  render "$([[ "$ADD" == true ]] && echo 1 || echo 0)"
  exit 0
fi

ADD_MISSING=$([[ ${#REPOS[@]} -gt 0 ]] && echo 1 || echo 0)

log() { echo "[sync-agents-md] $*"; }

sync_repo() {
  local repo="$1" default_branch current old new sha=""

  # set -e is ignored inside a function called with ||, so failures return explicitly
  default_branch=$(gh api "repos/$repo" --jq .default_branch) || return 1

  if current=$(gh api "repos/$repo/contents/$TARGET?ref=$default_branch" 2>/dev/null); then
    old=$(jq -r .content <<< "$current" | base64 -d)
    sha=$(jq -r .sha <<< "$current")
    new=$(render "$ADD_MISSING" <<< "$old") || return 1
    [[ "$new" == "$old" ]] && return 0
    log "UPDATE $repo :: $TARGET"
  elif [[ "$ADD_MISSING" == 1 ]]; then
    new=$(render 1 < /dev/null)
    log "ADD    $repo :: $TARGET"
  else
    return 0
  fi

  [[ "$DRY_RUN" == true ]] && return 0

  # Commit on a temporary branch, then move the sync branch in one step:
  # resetting the sync branch to the base first would leave an open PR empty and GitHub closes it
  local base_sha head_sha tmp_branch="$BRANCH-tmp"
  base_sha=$(gh api "repos/$repo/git/ref/heads/$default_branch" --jq .object.sha) || return 1
  gh api -X DELETE "repos/$repo/git/refs/heads/$tmp_branch" >/dev/null 2>&1 || true
  gh api "repos/$repo/git/refs" -f ref="refs/heads/$tmp_branch" -f sha="$base_sha" >/dev/null || return 1

  gh api -X PUT "repos/$repo/contents/$TARGET" \
    -f message="$TITLE"$'\n\n'"Signed-off-by: $AUTHOR_NAME <$AUTHOR_EMAIL>" \
    -f "author[name]=$AUTHOR_NAME" -f "author[email]=$AUTHOR_EMAIL" \
    -f "committer[name]=$AUTHOR_NAME" -f "committer[email]=$AUTHOR_EMAIL" \
    -f branch="$tmp_branch" \
    -f content="$(base64 <<< "$new" | tr -d '\n')" \
    ${sha:+-f sha="$sha"} >/dev/null || return 1

  head_sha=$(gh api "repos/$repo/git/ref/heads/$tmp_branch" --jq .object.sha) || return 1
  gh api -X PATCH "repos/$repo/git/refs/heads/$BRANCH" -f sha="$head_sha" -F force=true >/dev/null 2>&1 \
    || gh api "repos/$repo/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$head_sha" >/dev/null \
    || return 1
  gh api -X DELETE "repos/$repo/git/refs/heads/$tmp_branch" >/dev/null || return 1

  local body="Automated sync of the contribution policy block from https://github.com/$ORG/.github/blob/main/AGENT_MD_SNIPPETS.md. Edit the snippet there, not between the markers."
  if gh pr list --repo "$repo" --head "$BRANCH" --json number --jq '.[0].number' | grep -q .; then
    gh pr edit "$BRANCH" --repo "$repo" --body "$body" >/dev/null || return 1
    log "REFRESHED open PR in $repo"
  else
    gh pr create --repo "$repo" --base "$default_branch" --head "$BRANCH" --title "$TITLE" --body "$body" --label documentation \
      || gh pr create --repo "$repo" --base "$default_branch" --head "$BRANCH" --title "$TITLE" --body "$body"
  fi
}

# Commits are authored and signed off as the token's user to satisfy the DCO check
if [[ "$DRY_RUN" == false ]]; then
  read -r AUTHOR_NAME AUTHOR_ID < <(gh api user --jq '"\(.login) \(.id)"')
  [[ -n "${AUTHOR_ID:-}" ]] || { echo "Could not resolve the token's user" >&2; exit 1; }
  AUTHOR_EMAIL="$AUTHOR_ID+$AUTHOR_NAME@users.noreply.github.com"
fi

if [[ ${#REPOS[@]} -eq 0 ]]; then
  while IFS= read -r repo; do REPOS+=("$repo"); done \
    < <(gh repo list "$ORG" --limit 200 --no-archived --source --json nameWithOwner --jq '.[].nameWithOwner' \
      | grep -Ev -- '-ghsa-|-rehearsal$')
fi

FAILED=0
for repo in "${REPOS[@]}"; do
  sync_repo "$repo" || { log "WARN: failed for $repo"; FAILED=1; }
done

log "Done."
exit "$FAILED"
