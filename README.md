# demo-merge-protection

Sandbox repo to validate how Mergify injects a **GitHub ruleset** on `main` as
**merge protection** conditions on the merge queue.

Headline target: the `github-require-last-push-approval` condition auto-injected
from a ruleset's `require_last_push_approval`, gated by
`HONOR_REQUIRE_LAST_PUSH_APPROVAL_FOR_ORGS` — flipped to `*` (all orgs) in
[Mergifyio/monorepo#33574](https://github.com/Mergifyio/monorepo/pull/33574)
(MRGFY-1900).

## What gets injected

`branch_protection_injection_mode: queue` (in `.mergify.yml`) makes Mergify read
the ruleset on the target branch and convert each rule into a queue/merge
condition:

| Ruleset rule (`rulesets/main-protection.json`) | Injected condition |
| --- | --- |
| `pull_request.required_approving_review_count: 1` | `#approved-reviews-by >= 1` |
| `pull_request.require_last_push_approval: true` | `github-require-last-push-approval` *(flag-gated)* |
| `pull_request.required_review_thread_resolution: true` | `#review-threads-unresolved = 0` |
| `required_status_checks: [ci]` | `check-success=ci or check-neutral=ci or check-skipped=ci` |

The queue itself declares only `base = main`; everything above is injected, so
the PR's Mergify **Summary** check is where you watch the feature work.

## Layout

```
.mergify.yml                  merge queue with injection enabled
rulesets/main-protection.json the GitHub-side ruleset (the thing under test)
scripts/setup-ruleset.sh      applies the ruleset via `gh api`
.github/workflows/ci.yml      job "ci" -> the required status check context
src/, tests/                  trivial code so PRs and CI have something to do
```

## Setup

1. **Push `main`** so the default branch, `.mergify.yml`, and CI workflow exist.
2. **Install Mergify** on `mergify-sandbox/demo-merge-protection`.
3. **Apply the ruleset:**
   ```bash
   ./scripts/setup-ruleset.sh          # or --replace to recreate
   ```
4. Confirm the rules resolve on the branch:
   ```bash
   gh api repos/mergify-sandbox/demo-merge-protection/rules/branches/main
   ```

## Validate

Open a PR that edits `src/calculator.py`, label it `queue`, and read the Mergify
**Summary** check on the PR.

| Scenario | Expected |
| --- | --- |
| PR opened, CI not yet green | Summary lists the injected `check-success=ci`, `#approved-reviews-by >= 1`, `#review-threads-unresolved = 0` (and `github-require-last-push-approval` once the flag covers the org) as unmet. |
| 1 approval from a **different** user than the last pusher | `#approved-reviews-by >= 1` ✅ and `github-require-last-push-approval` ✅ → PR queues and merges. |
| Author pushes a commit **after** the only approval | `github-require-last-push-approval` flips ❌ (last pusher's own work isn't counted) → merge blocked until a fresh non-pusher approval. This is the PR #33574 behavior. |
| Set `branch_protection_injection_mode: none` and re-test | None of the ruleset conditions appear in Summary → merges with no protection. Confirms the injection is what enforces them. |

## The flag nuance (important)

`#approved-reviews-by`, `check-success`, and `#review-threads-unresolved` inject
for **any** org. `github-require-last-push-approval` injects **only** for orgs in
`HONOR_REQUIRE_LAST_PUSH_APPROVAL_FOR_ORGS`. So to see that specific condition on
`mergify-sandbox`, the env running the queue must have PR #33574 deployed (flag
= `*`) or the flag must explicitly include this org. The other three conditions
validate the injection mechanism regardless.

## Bypass actors

`rulesets/main-protection.json` ships with `bypass_actors: []`, so injection is
unambiguously active and GitHub enforces the rules too. If GitHub's own
enforcement blocks Mergify from merging (e.g. `fast-forward` / batch PRs, or
`strict_required_status_checks_policy`), add Mergify as a bypass actor with
**`always`** mode — injection still happens, but Mergify can merge. Use
**`exempt`** mode to make Mergify skip a ruleset's injection entirely. See
<https://docs.mergify.com/merge-queue/github-rulesets/>.
