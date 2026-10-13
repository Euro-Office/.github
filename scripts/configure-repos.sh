#!/usr/bin/env bash
# Applies the org-wide repo settings: auto-merge on, Discussions off, and a "main"
# ruleset that blocks force pushes and deletions, requires 1 approval and requires
# the CI checks that ran on most of the last merged PRs.
# Commit comments cannot be set via API, disable them in the org settings instead.
# Usage: configure-repos.sh [--dry-run] OWNER/REPO [OWNER/REPO...]
set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && { DRY_RUN=true; shift; }
[ $# -gt 0 ] || { echo "Usage: $0 [--dry-run] OWNER/REPO [OWNER/REPO...]" >&2; exit 1; }

RULESET_NAME="main"
SAMPLE_PRS=10
# Run on PRs but must not gate merging: cleanup on close, bots, release/publish steps
EXCLUDE_CHECKS='delete-pr-image|auto-approve|publish|release'

# Checks that ran from pull_request workflows (or non-Actions apps like DCO) on a commit
pr_checks() {
  local repo=$1 sha=$2 suites
  suites=$(gh api --paginate "repos/$repo/actions/runs?head_sha=$sha" \
    --jq '.workflow_runs[] | select(.event | startswith("pull_request")) | .check_suite_id' | jq -s .)
  gh api --paginate "repos/$repo/commits/$sha/check-runs" --jq '.check_runs[]' |
    jq -s --argjson suites "$suites" --arg exclude "$EXCLUDE_CHECKS" '[.[]
      | select(.app.slug != "github-actions" or (.check_suite.id | IN($suites[])))
      | select(.conclusion == "success" or .conclusion == "failure")
      | select(.name | test($exclude; "i") | not)
      | {context: .name, integration_id: .app.id}] | unique'
}

# Checks that ran on at least half of the last merged PRs, so path-filtered workflows
# and PRs without CI (e.g. opened by bots via GITHUB_TOKEN) drop out
required_checks() {
  local repo=$1 sha
  for sha in $(gh pr list -R "$repo" --state merged --limit "$SAMPLE_PRS" --json headRefOid --jq '.[].headRefOid'); do
    pr_checks "$repo" "$sha"
  done | jq -s 'length as $n | [.[][]] | group_by(.) | map(select(length * 2 >= $n) | .[0])'
}

ruleset() {
  jq -n --arg name "$RULESET_NAME" --argjson checks "$1" '{
    name: $name,
    target: "branch",
    enforcement: "active",
    conditions: { ref_name: { include: ["refs/heads/main"], exclude: [] } },
    rules: ([
      { type: "non_fast_forward" },
      { type: "deletion" },
      { type: "pull_request", parameters: {
          required_approving_review_count: 1,
          dismiss_stale_reviews_on_push: false,
          require_code_owner_review: false,
          require_last_push_approval: false,
          required_review_thread_resolution: false
      } }
    ] + if $checks == [] then [] else [
      { type: "required_status_checks", parameters: {
          strict_required_status_checks_policy: false,
          required_status_checks: $checks
      } }
    ] end)
  }'
}

for repo in "$@"; do
  echo "==> $repo"
  checks=$(required_checks "$repo")
  jq -r 'if . == [] then "    required checks: none found" else "    required checks:", (.[] | "      - \(.context)") end' <<<"$checks"
  $DRY_RUN && continue

  gh repo edit "$repo" --enable-auto-merge --enable-discussions=false

  id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$RULESET_NAME\") | .id")
  if [ -n "$id" ]; then
    ruleset "$checks" | gh api -X PUT "repos/$repo/rulesets/$id" --input - >/dev/null
  else
    ruleset "$checks" | gh api -X POST "repos/$repo/rulesets" --input - >/dev/null
  fi
done
