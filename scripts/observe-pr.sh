#!/usr/bin/env bash
# Snapshot the parity-relevant state of a PR for MRGFY-7814: GitHub
# reviewDecision, REST mergeable_state, GraphQL mergeStateStatus, every review's
# state@commit_id by author, the head sha, and Mergify's own check on the head.
#
#   ./scripts/observe-pr.sh <pr-number>
set -euo pipefail
REPO="${REPO:-mergify-sandbox/demo-ruleset-injection}"
PR="$1"

echo "=== PR #$PR ==="
gh api "repos/$REPO/pulls/$PR" \
  --jq '"head:         \(.head.sha[0:8])\nmergeable:    \(.mergeable)\nmergeable_state (REST): \(.mergeable_state)"'

gh pr view "$PR" --repo "$REPO" --json reviewDecision,mergeStateStatus \
  --jq '"reviewDecision:        \(.reviewDecision)\nmergeStateStatus (GQL): \(.mergeStateStatus)"'

echo "-- reviews: state  commit_id  author --"
gh api "repos/$REPO/pulls/$PR/reviews" \
  --jq '.[] | "\(.state)\t\(.commit_id[0:8])\t\(.user.login)"'

echo "-- Mergify check on head --"
sha=$(gh api "repos/$REPO/pulls/$PR" --jq .head.sha)
gh api "repos/$REPO/commits/$sha/check-runs" \
  --jq '.check_runs[] | select(.app.slug=="mergify") | "\(.name): \(.status)/\(.conclusion // "pending")  \(.output.title // "")"'
