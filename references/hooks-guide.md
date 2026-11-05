# Code Review Hooks Guide

Hooks allow teams to execute automated actions at specific stages of the code review lifecycle, integrate with CI/CD pipelines, trigger notifications, or block Git actions when issues are detected.

---

## 1. Lifecycle Hooks in `.ai/review.yml`

Configure commands in `.ai/review.yml`:

```yaml
hooks:
  # Runs before the review surface analysis starts
  pre_review: "bash scripts/pre-review-check.sh"

  # Runs after the review report has been generated
  post_review: "bash scripts/notify-slack.sh"

  # Runs only when P0 / Blocker findings are discovered
  on_blocker: "echo 'CRITICAL P0 FOUND - Block merge' >&2"

  # Runs when the review verdict is clean (APPROVE)
  on_approved: "bash scripts/ci-report-clean.sh"
```

### Environment Variables Passed to Hooks

When a hook is executed via `scripts/run-hook.sh`, the following environment variables are exported:

| Variable | Description | Example |
|---|---|---|
| `CODE_REVIEW_HOOK` | Name of the hook event | `post_review`, `on_blocker` |
| `CODE_REVIEW_VERDICT` | Review verdict | `APPROVE`, `REQUEST_CHANGES`, `COMMENT` |
| `CODE_REVIEW_P0_COUNT`| Number of P0 findings detected | `0`, `2` |

---

## 2. Git Hooks (`pre-commit` & `pre-push`)

Install the git hooks using:

```bash
bash scripts/install-hooks.sh
```

- **`pre-commit`**: Runs fast linters (`scripts/run-linters.sh`) specifically on staged files before commit.
- **`pre-push`**: Runs test suite (`scripts/run-tests.sh`) before pushing to remote repository.

---

## 3. Testing Hooks Manually

You can test any configured hook via the CLI:

```bash
bash scripts/run-hook.sh pre_review
bash scripts/run-hook.sh on_blocker --verdict REQUEST_CHANGES --p0-count 2
bash scripts/run-hook.sh on_approved --verdict APPROVE --p0-count 0
```
