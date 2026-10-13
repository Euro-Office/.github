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

# Per PR: which workflows were triggered/completed, which checks ran and which were
# cancelled or skipped. Non-Actions apps like DCO count as their own workflow.
pr_checks() {
  local repo=$1 sha=$2 runs
  runs=$(gh api --paginate "repos/$repo/actions/runs?head_sha=$sha" \
    --jq '.workflow_runs[] | select(.event | startswith("pull_request")) | {suite: .check_suite_id, wf: .workflow_id}' | jq -s .)
  gh api --paginate "repos/$repo/commits/$sha/check-runs" --jq '.check_runs[]' |
    jq -s --argjson runs "$runs" --arg exclude "$EXCLUDE_CHECKS" '
      ($runs | map({key: (.suite | tostring), value: .wf}) | from_entries) as $wf
      | [.[]
        | .wf = (if .app.slug == "github-actions" then $wf[.check_suite.id | tostring] else "app:\(.app.slug)" end)
        | select(.wf != null and (.name | test($exclude; "i") | not))] as $checks
      | ($checks | map(select(.conclusion == "success" or .conclusion == "failure"))) as $done
      | {
          triggered: ([$runs[].wf] + [$checks[].wf] | unique),
          completed: ([$done[].wf] | unique),
          ran: ([$done[] | {context: .name, integration_id: .app.id, wf}] | unique),
          # Matrix jobs cancelled before expanding only report their base name
          abstain: ([$checks[] | select(.conclusion == "cancelled" or .conclusion == "skipped") | .name | sub(" \\(.*"; "")] | unique)
        }'
}

# Vote over the last merged PRs with completed Actions CI (drops bot PRs without CI):
# - a workflow must have been triggered on at least half of them (drops path-filtered ones)
# - a check is required if it ran at least as often as it was missing from a completed
#   run of its workflow; cancelled/skipped runs don't vote, so renamed matrix jobs and
#   cancelled builds don't push current jobs out
# - it must have run in the newest PR where its workflow completed (drops renamed jobs)
required_checks() {
  local repo=$1 sha
  for sha in $(gh pr list -R "$repo" --state merged --limit "$SAMPLE_PRS" --json headRefOid,mergedAt \
      --jq 'sort_by(.mergedAt) | reverse | .[].headRefOid'); do
    pr_checks "$repo" "$sha"
  done | jq -s '
    map(select(any(.completed[]; type == "number"))) as $prs
    | [$prs[].ran[]] | unique
    | map(. as $c
        | select(([$prs[] | select(.triggered | index([$c.wf]))] | length) * 2 >= ($prs | length))
        | select(([$prs[] | select(.ran | index([$c]))] | length)
              >= ([$prs[] | select((.completed | index([$c.wf])) and (.ran | index([$c]) | not)
                    and (.abstain | index([$c.context | sub(" \\(.*"; "")]) | not))] | length))
        | select([$prs[] | select((.completed | index([$c.wf])) and (.abstain | index([$c.context | sub(" \\(.*"; "")]) | not))][0]
            | .ran | index([$c]))
        | {context, integration_id})
    | unique'
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
