# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> ## ⚠️ Public repository — keep it secret-free
> This repo and everything written into it (commits, PR titles/bodies, comments,
> configs, branch names, this file) is world-readable. **Do not introduce "secret
> sauce":** customer/account names from real cases, internal ticket IDs or links,
> production identifiers or data, internal service / code-path names, or any
> confidential analysis of how Mergify or GitHub behave internally. Describe tests
> generically. The only secret here is a PAT, which lives **only** in the
> gitignored `.env` — never echo it, never commit it.

## Purpose

Sandbox for validating that **GitHub repository ruleset** conditions are injected
into Mergify's merge gate and enforced **in parity with GitHub** — Mergify holds or
merges a PR exactly when GitHub blocks or accepts it. The repo's trivial Python
(`src/`, `tests/`) only exists so PRs and CI have something to do; the subject under
test is the config in `.mergify.yml` + `rulesets/`.

## Commands

```bash
python -m pytest -q                        # the placeholder test suite (CI job "ci")
mergify config validate                    # validate .mergify.yml against the schema
mergify config simulate <PR_URL>           # what Mergify would decide on a live PR (see below)
./scripts/setup-ruleset.sh [--replace]     # apply rulesets/main-protection.json via gh api (repo admin)
./scripts/observe-pr.sh <pr-number>        # snapshot the parity-relevant state of a PR
```

## How injection works

`.mergify.yml` declares a merge gate (currently a `merge-default` `pull_request_rules`
merge). Because the active branch ruleset enables a `pull_request` parameter (e.g.
`require_last_push_approval`) **and Mergify is not in the ruleset `bypass_actors`**,
Mergify injects the corresponding condition (e.g. `github-require-last-push-approval`)
into that gate automatically — it is intentionally *not* written in `.mergify.yml`.
Change the ruleset → change the gate, with no config edit.

- `rulesets/main-protection.json` is the ruleset under test. **Isolate the parameter
  you are testing**: strip unrelated gates (required status checks, review-thread
  resolution, code-owner) so only that parameter can block, and keep `bypass_actors`
  empty so GitHub enforces against Mergify's merge.
- Mergify reads `.mergify.yml` from the **default branch**, and caches it. After
  changing it, post an `@mergifyio refresh` comment to force a re-read.

## Parity-test methodology

Two GitHub accounts are enough:
- **R** — a human reviewer (the admin/owner account); gives approvals.
- **B** — a **non-reviewer machine account** with **Write**, **not** in `bypass_actors`.
  B is the **PR author *and* the pusher** — a reviewer can't approve their own PR, so
  with two accounts B must author it. A `User`-type collaborator is already set up for
  this; its PAT (Contents read/write) goes in `.env` as `GITHUB_TOKEN`.

Pattern (record both sides at each step and assert they agree):
1. B opens a PR at commit A.
2. R approves commit A.
3. B pushes a real change → new head. → the gate engages (e.g. blocks).
4. R (a non-pusher) approves the new head. → the gate clears.

At each step capture **GitHub** (`reviewDecision`, `mergeable_state` /
`mergeStateStatus`, `reviews[].commit_id`, and the merge-API accept/reject) and
**Mergify** (the injected condition + its hold/merge decision). Parity = Mergify's
decision == GitHub's accept/reject.

## Mechanics & gotchas (learned, easy to trip on)

- **Drive B's git ops via `gh api`** (Git Data / Contents API) with B's token instead
  of `git push`: the commit author/pusher becomes B, and no branch push is needed.
- **`gh` token pollution**: sourcing `.env` exports `GITHUB_TOKEN`, which `gh` prefers
  over the keyring. Use `env -u GITHUB_TOKEN -u GH_TOKEN gh …` for owner/admin calls
  and `GH_TOKEN="$BTOK" gh …` for B's calls.
- **Landing config on the gated default branch**: the active ruleset blocks direct
  pushes. Set the ruleset `enforcement=disabled` (admin `gh api`), push, then
  re-apply active with `setup-ruleset.sh --replace`. Pushing the default branch is a
  human step (push is guarded for the agent).
- **`mergify config simulate <PR_URL>`** evaluates the live config against the live
  PR **including injected ruleset conditions** (a condition tagged with the ruleset
  is the injected one). It's the authoritative read of Mergify's computation and
  doesn't merge anything — use it instead of waiting on async processing.
- **Direct `merge` action routes through the merge queue** in current Mergify; to
  observe a live merge, queue with an `@mergifyio queue` comment.
- **Interpreting `reviewDecision`**: with `require_last_push_approval` on, a
  post-approval push by a non-reviewer flips the aggregate `reviewDecision` to
  `REVIEW_REQUIRED` even though the approval *object* stays `APPROVED` at the old head
  (when dismiss-stale is off) — so `github-review-decision=APPROVED` is also unmet.
- **REST quirks**: the approve event is `event=APPROVE` (not `APPROVED`); quote
  `gh api` array fields (`-f 'labels[]=…'`) so zsh doesn't glob `[]`.
