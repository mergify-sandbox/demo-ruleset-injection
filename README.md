# demo-ruleset-injection

Sandbox repo showing how Mergify injects a **GitHub ruleset** on `main` into the
**merge queue** as merge-protection conditions.

## How it works

`branch_protection_injection_mode: queue` in `.mergify.yml` makes Mergify read
the ruleset on the target branch and turn each rule into a queue/merge
condition automatically:

| Ruleset rule (`rulesets/main-protection.json`) | Injected condition |
| --- | --- |
| `required_approving_review_count: 1` | `#approved-reviews-by >= 1` |
| `required_review_thread_resolution: true` | `#review-threads-unresolved = 0` |
| `required_status_checks: [ci]` | `check-success = ci` (or neutral / skipped) |

The queue itself declares only `base = main` — everything else is injected, so
changing the ruleset changes the merge gate with no `.mergify.yml` edit.

## Layout

```
.mergify.yml                   merge queue with injection enabled
rulesets/main-protection.json  the GitHub ruleset under test
scripts/setup-ruleset.sh       applies the ruleset via `gh api`
.github/workflows/ci.yml       job "ci" -> the required status check
src/, tests/                   trivial code so PRs and CI have something to do
```

## Setup

1. Push `main` so the default branch, `.mergify.yml`, and CI workflow exist.
2. Install Mergify on the repository and enable the merge queue.
3. Apply the ruleset:
   ```bash
   ./scripts/setup-ruleset.sh        # --replace to recreate
   ```

## Validate

Open a PR, label it `queue`, and queue it (`@mergifyio queue`). The merge-queue
status lists the injected ruleset conditions gating the merge — the PR waits on
`#approved-reviews-by >= 1` until it gets an approval. Flip
`branch_protection_injection_mode` to `none` and re-test: the ruleset conditions
vanish, confirming the injection is what enforces them.

See <https://docs.mergify.com/merge-queue/github-rulesets/>.
