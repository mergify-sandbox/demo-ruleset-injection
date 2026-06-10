#!/usr/bin/env bash
# Create (or recreate) the demo branch ruleset on `main` from
# rulesets/main-protection.json.
#
# This is the GitHub-side configuration whose conditions Mergify injects as
# merge protection. Requires `gh` authenticated with admin on the repo.
#
#   ./scripts/setup-ruleset.sh            # create the ruleset
#   ./scripts/setup-ruleset.sh --replace  # delete any same-named ruleset first
set -euo pipefail

REPO="${REPO:-mergify-sandbox/demo-ruleset-injection}"
PAYLOAD="$(dirname "$0")/../rulesets/main-protection.json"
NAME="$(jq -r .name "$PAYLOAD")"

if [[ "${1:-}" == "--replace" ]]; then
  existing="$(gh api "repos/$REPO/rulesets" --jq \
    ".[] | select(.name == \"$NAME\") | .id" 2>/dev/null || true)"
  for id in $existing; do
    echo "Deleting existing ruleset $id ($NAME)..."
    gh api -X DELETE "repos/$REPO/rulesets/$id"
  done
fi

echo "Creating ruleset \"$NAME\" on ${REPO}..."
gh api -X POST "repos/$REPO/rulesets" --input "$PAYLOAD" \
  --jq '"created ruleset id=\(.id) enforcement=\(.enforcement)"'

echo
echo "Verify on the head SHA of an open PR with:"
echo "  gh api repos/$REPO/rules/branches/main"
