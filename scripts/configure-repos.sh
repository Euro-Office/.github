#!/usr/bin/env bash
# Applies the org-wide repo settings: auto-merge on, PR branch updates allowed, Discussions off, and a "main"
# ruleset on the default branch that blocks force pushes and deletions, requires 1 approval and requires
# the CI checks listed below. The developer teams below may bypass it when merging a PR, org and repo admins always.
# A "release-tags" ruleset lets only those teams, the release team and admins create, move or delete v* tags,
# except on the odoo repos.
# Commit comments cannot be set via API, disable them in the org settings instead.
# Usage: configure-repos.sh [--dry-run] OWNER/REPO [OWNER/REPO...]
set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && { DRY_RUN=true; shift; }
[ $# -gt 0 ] || { echo "Usage: $0 [--dry-run] OWNER/REPO [OWNER/REPO...]" >&2; exit 1; }

RULESET_NAME="main"
TAG_RULESET_NAME="release-tags"

# Checks are pinned to the app that reports them, so nobody can fake them via the statuses API
DCO_APP_ID=1861
ACTIONS_APP_ID=15368

# Teams allowed to merge PRs without approval or passing checks, direct pushes stay blocked
# gh api orgs/Euro-Office/teams/SLUG --jq .id
BYPASS_TEAM_IDS="[18051093, 17868694]" # nextcloud-developers, ionos-developers
RELEASE_TEAM_ID=20148551 # release, holds eo-robot which tags via release/.github/workflows/tag.yml

# Required on every repo, one "APP_ID check name" per line.
# conventional-commits comes from workflow-templates/ and is only required where the synced workflow has that job.
GENERAL_CHECKS="$DCO_APP_ID DCO
$ACTIONS_APP_ID conventional-commits"
CONVENTIONAL_COMMITS_WORKFLOW=".github/workflows/conventional-commits.yml"

# Required per repo, reported by GitHub Actions, one check name per line. Names must match exactly, including the
# "..." GitHub appends when truncating long matrix job names. Never list jobs from workflows
# with pull_request paths filters: they never report on unrelated PRs and block merging.
repo_checks() {
  case "$1" in
    Euro-Office/core) echo "build
build-wasm
build-wasm-summary
changes" ;;
    Euro-Office/DesktopEditors) echo "brand-assets (euro-office)
brand-assets (nextcloud-office)
build-common (euro-office)
build-common (nextcloud-office)
build-linux (amd64, euro-office)
build-linux (amd64, nextcloud-office)
build-linux (arm64, euro-office)
build-linux (arm64, nextcloud-office)
build-macos (euro-office)
build-macos (nextcloud-office)
build-windows (amd64, euro-office)
build-windows (amd64, nextcloud-office)
build-windows (arm64, euro-office)
build-windows (arm64, nextcloud-office)
crosscompile-3rdparty-arm64
version" ;;
    # Lint, licences and artifact workflows are path-filtered per example, so they can't be required
    Euro-Office/document-server-integration) echo "e2e" ;;
    Euro-Office/documentation) echo "build" ;;
    Euro-Office/DocumentServer) echo "build (amd64, euro-office, documentserver, cluster-docs, cluster-example, cluster-utils)
build (amd64, nextcloud-office, nextcloud-office-documentserver, nextcloud-office-cluster-docs, n...
build (arm64, euro-office, documentserver, cluster-docs, cluster-example, cluster-utils)
build (arm64, nextcloud-office, nextcloud-office-documentserver, nextcloud-office-cluster-docs, n...
clone
e2e
upgrade" ;;
    Euro-Office/eurooffice-nextcloud) echo "Lint
Packaging filter
artifact
php-cs
php-lint (8.1)
php-lint (8.2)
php-lint (8.3)
php-lint (8.4)" ;;
    Euro-Office/release) echo "check" ;;
    Euro-Office/sdkjs) echo "build-test
code-style
unit-tests" ;;
    Euro-Office/server) echo "e2e" ;;
    Euro-Office/web-apps) echo "e2e
unit-tests" ;;
  esac
}

ruleset() {
  jq -n --arg name "$RULESET_NAME" --argjson checks "$1" --argjson teams "$BYPASS_TEAM_IDS" '{
    name: $name,
    target: "branch",
    enforcement: "active",
    bypass_actors: ([$teams[] | { actor_id: ., actor_type: "Team", bypass_mode: "pull_request" }] + [
      { actor_id: 1, actor_type: "OrganizationAdmin", bypass_mode: "always" },
      { actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always" }
    ]),
    conditions: { ref_name: { include: ["~DEFAULT_BRANCH"], exclude: [] } },
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

tag_ruleset() {
  jq -n --arg name "$TAG_RULESET_NAME" --argjson teams "$BYPASS_TEAM_IDS" --argjson release "$RELEASE_TEAM_ID" '{
    name: $name,
    target: "tag",
    enforcement: "active",
    bypass_actors: ([$teams[], $release | { actor_id: ., actor_type: "Team", bypass_mode: "always" }] + [
      { actor_id: 1, actor_type: "OrganizationAdmin", bypass_mode: "always" },
      { actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always" }
    ]),
    conditions: { ref_name: { include: ["refs/tags/v*"], exclude: [] } },
    rules: [{ type: "creation" }, { type: "update" }, { type: "deletion" }]
  }'
}

# Usage: upsert_ruleset REPO NAME < ruleset.json
upsert_ruleset() {
  local id
  id=$(gh api "repos/$1/rulesets" --jq ".[] | select(.name == \"$2\") | .id")
  if [ -n "$id" ]; then
    gh api -X PUT "repos/$1/rulesets/$id" --input - >/dev/null
  else
    gh api -X POST "repos/$1/rulesets" --input - >/dev/null
  fi
}

for repo in "$@"; do
  echo "==> $repo"
  general=$GENERAL_CHECKS
  if ! gh api -H "Accept: application/vnd.github.raw" "repos/$repo/contents/$CONVENTIONAL_COMMITS_WORKFLOW" 2>/dev/null |
      grep -q '^  conventional-commits:$'; then
    echo "    warning: $CONVENTIONAL_COMMITS_WORKFLOW missing or outdated, not requiring conventional-commits" >&2
    general=$(grep -v ' conventional-commits$' <<<"$general")
  fi
  checks=$({
    jq -R 'select(. != "") | capture("^(?<integration_id>[0-9]+) (?<context>.+)$") | .integration_id |= tonumber' <<<"$general"
    jq -R --argjson app "$ACTIONS_APP_ID" 'select(. != "") | {context: ., integration_id: $app}' <<<"$(repo_checks "$repo")"
  } | jq -s .)
  jq -r '"    required checks:", (.[] | "      - \(.context)")' <<<"$checks"
  $DRY_RUN && continue

  gh repo edit "$repo" --enable-auto-merge --allow-update-branch --enable-discussions=false

  ruleset "$checks" | upsert_ruleset "$repo" "$RULESET_NAME"
  [[ "$repo" == *odoo* ]] || tag_ruleset | upsert_ruleset "$repo" "$TAG_RULESET_NAME"
done
