#!/usr/bin/env bash
# Labels open issues and PRs that have no label yet, and can draft a first triage reply.
# Everything asks a small model, except dependency update PRs.
# Model: GitHub Models inside GitHub Actions, Claude Haiku locally (claude CLI without tools).
# Usage: ./ai-label.sh [--prs | --issues] [--repo OWNER/REPO | --item OWNER/REPO#N] [--limit N]
#                      [--dry-run] [--triage [--post]]
#   --prs, --issues  Only pull requests or only issues (default: both)
#   --repo           Only this repo (default: every repo in the org)
#   --item           Only this issue or PR, used by the workflow template
#   --limit          Process at most N items
#   --dry-run        Print proposed labels without applying them
#   --triage         Issues only, local only: draft a first reply, possible duplicates, missing info
#   --post           With --triage: ask per draft whether to post it, edit it or skip it
# Env: AI_LABEL_BACKEND=github|claude overrides the backend choice

set -euo pipefail

ORG="Euro-Office"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Labels the model may pick, all of them are defined in sync-labels.sh. At most 1 type and 2 areas
MODEL_LABELS='{
  "type": ["bug", "enhancement", "documentation", "question"],
  "area": ["build", "docker", "packages", "tests", "design", "performance", "security", "i18n", "integration",
           "format: odf", "format: ooxml", "format: pdf"],
  "extra": ["linux", "windows", "macos", "mobile", "regression", "high"]
}'
GITHUB_MODEL="openai/gpt-4.1-mini"
MAX_BODY=4000
RATE_LIMITED=75

log() { echo "[ai-label] $*" >&2; }

# Dependency update PRs are labeled without a model: bot authors or a deps scope
is_dependency_pr() {
  local title="$1" author="$2" re='^[a-z]+\(deps(-dev)?\)!?: '
  [[ "$author" == "renovate[bot]" || "$author" == "dependabot[bot]" || "$title" =~ $re ]]
}

# Extracts the first JSON object from model output, which may wrap it in prose or code fences
parse_json() {
  jq -Rsce '(capture("(?s)(?<j>\\{.*\\})").j | try fromjson catch null)
    // (capture("(?s)(?<j>\\{.*?\\})").j | fromjson) | objects' 2>/dev/null
}

# Keeps allowlisted model labels in the model's order: at most 1 type, 2 areas, any extras
filter_labels() {
  jq -r --argjson g "$MODEL_LABELS" '
    [.labels[]? | strings] | reduce .[] as $l ([]; if index([$l]) then . else . + [$l] end)
    | (map(select(IN($g.type[])))[:1] + map(select(IN($g.area[])))[:2] + map(select(IN($g.extra[]))))[]' <<< "$1"
}

backend() {
  if [[ -n "${AI_LABEL_BACKEND:-}" ]]; then echo "$AI_LABEL_BACKEND"
  elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo github
  else echo claude
  fi
}

# Sends stdin as the user message with $1 as system prompt file, prints the reply
ask_model() {
  local prompt_file="$1"
  if [[ "$(backend)" == github ]]; then
    local response status token="${GH_TOKEN:-$(gh auth token)}"
    response=$(jq -Rsc --rawfile sys "$prompt_file" --arg model "$GITHUB_MODEL" \
        '{model: $model, temperature: 0, messages: [{role: "system", content: $sys}, {role: "user", content: .}]}' \
      | curl -sS -w '\n%{http_code}' https://models.github.ai/inference/chat/completions \
          -H @<(printf 'Authorization: Bearer %s\n' "$token") -H 'Content-Type: application/json' -d @-)
    status=${response##*$'\n'}
    response=${response%$'\n'*}
    [[ "$status" == 429 ]] && return "$RATE_LIMITED"
    [[ "$status" == 200 ]] || { log "GitHub Models returned $status: $response"; return 1; }
    jq -r '.choices[0].message.content' <<< "$response" 2>/dev/null \
      || { log "unexpected GitHub Models reply: ${response:0:200}"; return 1; }
  else
    # No tools, no MCP servers, no settings or hooks, empty cwd: issue text can only shape the reply
    (cd "$WORKDIR/empty" && claude -p --model haiku --tools "" --strict-mcp-config \
      --setting-sources "" --system-prompt-file "$prompt_file")
  fi
}

repo_labels() {
  local cache="$WORKDIR/labels-${1//\//_}.json"
  [[ -f "$cache" ]] || gh label list --repo "$1" --limit 500 --json name --jq '[.[].name]' > "$cache"
  cat "$cache"
}

item_text() {
  jq -r --argjson max "$MAX_BODY" \
    '"<item>\nType: \(if .pull_request then "pull request" else "issue" end)\nTitle: \(.title)\nBody:\n\((.body // "")[:$max])\n</item>"' <<< "$1"
}

list_items() {
  local q="is:open no:label archived:false"
  if [[ -n "$REPO" ]]; then q+=" repo:$REPO"; else q+=" org:$ORG"; fi
  case "$TYPE" in prs) q+=" is:pr" ;; issues) q+=" is:issue" ;; esac
  gh api -X GET search/issues --paginate -f q="$q" -f per_page=100 --jq '.items[] | tojson'
}

triage_item() {
  local item="$1" repo="$2" number="$3" title words candidates out reply
  title=$(jq -r .title <<< "$item")
  # ponytail: title keyword search for duplicates, embeddings if it misses too many
  words=$(tr -cs '[:alnum:]' '\n' <<< "$title" | awk 'length > 3' | head -6 | paste -sd ' ' - | sed 's/ / OR /g')
  candidates=""
  [[ -n "$words" ]] && candidates=$(gh api -X GET search/issues -f per_page=15 \
    -f q="repo:$repo is:issue in:title $words" \
    --jq ".items[] | select(.number != $number) | \"#\(.number) [\(.state)] \(.title)\"")

  out=$({ item_text "$item"; printf '<candidates>\n%s\n</candidates>\n' "$candidates"; } \
    | ask_model "$HERE/ai-triage.prompt.md" | parse_json) || { log "$repo#$number: no triage reply"; return 1; }

  reply=$(jq -r '.reply // ""' <<< "$out")
  echo "  needs info: $(jq -r '.needs_info // false' <<< "$out")"
  jq -r '.duplicates[]? | numbers' <<< "$out" | while read -r n; do
    grep "^#$n " <<< "$candidates" | sed 's/^/  possible duplicate: /' || true
  done
  printf '  draft reply:\n%s\n' "$(sed 's/^/    /' <<< "$reply")"

  [[ "$POST" == true && -n "$reply" ]] || return 0
  local draft="$WORKDIR/reply.md" answer
  printf '%s\n' "$reply" > "$draft"
  while true; do
    read -r -p "  Post to $repo#$number? [y]es / [e]dit / [N]o: " answer < /dev/tty
    case "$answer" in
      y|Y) gh issue comment "$number" --repo "$repo" --body-file "$draft" >/dev/null && log "posted"; return ;;
      e|E) sh -c "${EDITOR:-vi} \"\$1\"" sh "$draft" < /dev/tty > /dev/tty; sed 's/^/    /' "$draft" ;;
      *) return 0 ;;
    esac
  done
}

process_item() {
  local item="$1" repo number title labels="" missing="" out rc=0 l
  repo=$(jq -r '.repository_url | sub(".*/repos/"; "")' <<< "$item")
  number=$(jq -r .number <<< "$item")
  title=$(jq -r .title <<< "$item")

  if [[ "$(jq '.labels | length' <<< "$item")" -gt 0 ]]; then
    log "$repo#$number already labeled, skipping"
    return 0
  fi

  if jq -e .pull_request >/dev/null <<< "$item"; then
    is_dependency_pr "$title" "$(jq -r .user.login <<< "$item")" && labels=dependencies
  fi

  if [[ -z "$labels" ]]; then
    out=$(item_text "$item" | ask_model "$HERE/ai-label.prompt.md") || rc=$?
    [[ $rc -eq 0 ]] || return "$rc"
    out=$(parse_json <<< "$out") || { log "$repo#$number: unparseable model reply"; return 1; }
    labels=$(filter_labels "$out")
  fi

  # Labels the repo lacks are reported, run sync-labels.sh to create them
  local present=""
  while IFS= read -r l; do
    [[ -n "$l" ]] || continue
    if jq -e --arg l "$l" 'any(.[]; . == $l)' >/dev/null <<< "$(repo_labels "$repo")"; then
      present+="$l"$'\n'
    else
      missing+="${missing:+, }$l"
    fi
  done <<< "$labels"
  labels=${present%$'\n'}

  echo "$repo#$number  $title"
  echo "  labels: $(paste -sd ',' - <<< "${labels:-(none)}")${missing:+ (not in repo: $missing)}"

  if [[ -n "$labels" && "$DRY_RUN" == false ]]; then
    local args=()
    while IFS= read -r l; do args+=(-f "labels[]=$l"); done <<< "$labels"
    gh api -X POST "repos/$repo/issues/$number/labels" "${args[@]}" >/dev/null || return 1
  fi

  if [[ "$TRIAGE" == true ]] && ! jq -e .pull_request >/dev/null <<< "$item"; then
    triage_item "$item" "$repo" "$number"
  fi
}

main() {
  TYPE="" REPO="" ITEM="" LIMIT=1000 DRY_RUN=false TRIAGE=false POST=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prs) TYPE="prs" ;;
      --issues) TYPE="issues" ;;
      --repo) REPO="$2"; shift ;;
      --item) ITEM="$2"; shift ;;
      --limit) LIMIT="$2"; shift ;;
      --dry-run) DRY_RUN=true ;;
      --triage) TRIAGE=true ;;
      --post) POST=true ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
  done
  [[ "$TRIAGE" == true && -n "${GITHUB_ACTIONS:-}" ]] && { log "--triage only runs locally, a human reviews every reply"; exit 1; }
  [[ "$POST" == true && "$TRIAGE" == false ]] && { log "--post needs --triage"; exit 1; }
  [[ "$POST" == true && "$DRY_RUN" == true ]] && { log "--post and --dry-run exclude each other"; exit 1; }

  WORKDIR=$(mktemp -d)
  trap 'rm -rf "$WORKDIR"' EXIT
  mkdir "$WORKDIR/empty"

  # Collected up front: labeling items shifts the search result pages
  if [[ -n "$ITEM" ]]; then
    gh api "repos/${ITEM%#*}/issues/${ITEM##*#}" --jq tojson > "$WORKDIR/items"
  else
    list_items > "$WORKDIR/all"
    head -n "$LIMIT" "$WORKDIR/all" > "$WORKDIR/items"
  fi
  log "$(wc -l < "$WORKDIR/items" | tr -d ' ') items, backend $(backend)"

  local failed=0 rc
  while IFS= read -r item <&3; do
    rc=0
    process_item "$item" || rc=$?
    if [[ $rc -eq $RATE_LIMITED ]]; then
      log "GitHub Models rate limit reached, rerun later to continue"
      break
    fi
    [[ $rc -eq 0 ]] || failed=1
  done 3< "$WORKDIR/items"
  exit "$failed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
