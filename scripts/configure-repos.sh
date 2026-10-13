#!/usr/bin/env bash
# Applies the org-wide repo settings: auto-merge on, Discussions off, and a "main"
# ruleset that blocks force pushes and deletions, requires 1 approval and requires
# the CI checks listed below.
# Commit comments cannot be set via API, disable them in the org settings instead.
# Usage: configure-repos.sh [--dry-run] OWNER/REPO [OWNER/REPO...]
set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && { DRY_RUN=true; shift; }
[ $# -gt 0 ] || { echo "Usage: $0 [--dry-run] OWNER/REPO [OWNER/REPO...]" >&2; exit 1; }

RULESET_NAME="main"

# Checks are pinned to the app that reports them, so nobody can fake them via the statuses API
DCO_APP_ID=1861
ACTIONS_APP_ID=15368

# Required on every repo, reported by the DCO app
GENERAL_CHECKS="DCO"

# Required per repo, reported by GitHub Actions, one check name per line. Names must match exactly, including the
# "..." GitHub appends when truncating long matrix job names.
repo_checks() {
  case "$1" in
    Euro-Office/core) echo "build
build-wasm
build-wasm-summary
changes" ;;
    Euro-Office/DesktopEditors) echo "brand-assets (euro-office, false)
brand-assets (nextcloud-office, ./brands/nextcloud-office-brand/brand-desktop.hcl, nextcloud-offi...
build-common (euro-office, desktop-common, Euro-Office, Euro-Office, .)
build-common (nextcloud-office, no-desktop-common, Nextcloud Office, Nextcloud Office, ./build/br...
build-linux (amd64, euro-office, Euro-Office, Euro-Office, .)
build-linux (amd64, nextcloud-office, Nextcloud Office, Nextcloud Office, ./build/brands/nextclou...
build-linux (arm64, euro-office, Euro-Office, Euro-Office, .)
build-linux (arm64, nextcloud-office, Nextcloud Office, Nextcloud Office, ./build/brands/nextclou...
build-macos (euro-office, desktop-apps/macos/Euro-Office.xcodeproj, Euro-Office-arm, Euro-Office....
build-macos (nextcloud-office, desktop-apps/macos/Euro-Office.xcodeproj, Euro-Office-arm, Nextclo...
build-windows (amd64, euro-office, Euro-Office, Euro-Office, false)
build-windows (amd64, nextcloud-office, Nextcloud Office, Nextcloud Office, true)
build-windows (arm64, euro-office, Euro-Office, Euro-Office, false)
build-windows (arm64, nextcloud-office, Nextcloud Office, Nextcloud Office, true)
crosscompile-3rdparty-arm64
version" ;;
    Euro-Office/document-server-integration) echo "Lint
artifact
licences
licences (8.2)
lint
lint (8.2)" ;;
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
    Euro-Office/sdkjs) echo "build-test
code-style
unit-tests" ;;
    Euro-Office/server) echo "e2e" ;;
    Euro-Office/web-apps) echo "e2e
unit-tests" ;;
  esac
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
  checks=$({
    jq -R --argjson app "$DCO_APP_ID" 'select(. != "") | {context: ., integration_id: $app}' <<<"$GENERAL_CHECKS"
    jq -R --argjson app "$ACTIONS_APP_ID" 'select(. != "") | {context: ., integration_id: $app}' <<<"$(repo_checks "$repo")"
  } | jq -s .)
  jq -r '"    required checks:", (.[] | "      - \(.context)")' <<<"$checks"
  $DRY_RUN && continue

  gh repo edit "$repo" --enable-auto-merge --enable-discussions=false

  id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$RULESET_NAME\") | .id")
  if [ -n "$id" ]; then
    ruleset "$checks" | gh api -X PUT "repos/$repo/rulesets/$id" --input - >/dev/null
  else
    ruleset "$checks" | gh api -X POST "repos/$repo/rulesets" --input - >/dev/null
  fi
done
