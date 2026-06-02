# Review Memory Guide

Review memory stores project-specific knowledge that persists across review sessions. It makes the reviewer more accurate on every subsequent review.

## Memory File Location

Default: `.ai/review-memory.md`
Custom: set `review.memory.file` in `.ai/review.yml`

## Memory File Format

```markdown
# Review Memory

## Architecture

- [Decision or invariant that affects how code should be judged]
- The project uses DDD-style boundaries; keep domain logic out of controllers.
- Prefer constructor injection over service locator patterns.

## Recurring Issues

- [Pattern that frequently surfaces in reviews — raise sensitivity here]
- Reports in the analytics module are prone to N+1 queries due to missing eager loading.
- Transaction boundaries are often too wide around external HTTP calls.

## Accepted Patterns

- [Intentional patterns that look wrong but have been approved]
- Migrations may be split into schema and backfill steps for zero-downtime deploys.
- LegacyReportBuilder uses service locator intentionally (scheduled for removal in Q3).

## False Positives

- [Tool or lens findings that do not apply to this project]
- Generated API clients in src/generated/ intentionally violate local naming conventions.
- PHPStan level 8 flags mixed types in generated DTO classes — acceptable.

## Custom Rules

- [Project-specific rules that override or extend default review criteria]
- All POST endpoints must be idempotent or document why they are not.
```

## Auto-Update Behavior

| Config setting | Behavior |
|---|---|
| `auto_update: false` (default) | Skill proposes memory entries for user review before writing |
| `auto_update: true` | Skill appends useful lessons after each review automatically |

Use `auto_update: false` on shared repos to keep memory changes auditable via git.

## Memory Quality Guidelines

**Keep entries that are**:
- **Specific**: "Reports in the analytics module" not "reports"
- **Durable**: Decisions unlikely to change in the next 3 months
- **Actionable**: A future reviewer can act on it without further clarification

**Remove entries that**:
- Describe already-fixed bugs
- Reference deleted modules or deprecated patterns
- Are too vague to guide action

## When to Write Memory

Write a memory entry when a review reveals:
- A recurring bug pattern specific to this codebase
- An architectural decision that would look like a mistake without context
- A known false positive from a tool that is otherwise useful
- A team convention not captured anywhere else

Do **not** write memory for:
- General best practices already in the skill's lenses
- Issues that belong in the code itself or in docs
- Temporary exceptions that expire in days

## Example: Initial Memory After First Review

```markdown
# Review Memory

## Architecture

- DDD boundaries enforced: `Domain/` must not import from `Infrastructure/`.
- All business logic lives in Action classes under `App/Actions/`.
- Repositories are injected into Actions, never into Entities.

## Recurring Issues

- Missing `with('items')` eager loading on `Order` queries in reports.
- External HTTP calls (Stripe, SendGrid) are sometimes placed inside DB transactions.

## Accepted Patterns

- `LegacyPricingEngine` class uses array-based config instead of typed DTOs — approved until Q4 migration.
- Some admin-only endpoints skip CSRF checks intentionally (marked with `@csrf_exempt`).

## False Positives

- PHPStan flags `mixed` return types in `GeneratedApiClient` — auto-generated, do not flag.
- ESLint `no-explicit-any` fires on third-party type shims in `src/types/shims/` — ignore.
```

## Memory and Sensitive Information

**Never store** secrets, credentials, tokens, or PII in memory files.

Memory files should be committed to version control so all reviewers share the same project knowledge. If a project uses `.gitignore` to exclude `.ai/`, document why.
