# smart-code-review

Context-aware AI code review with persistent memory, configurable rules, specialist lenses, and automated tool integration.

Works with: **PHP/Laravel**, **TypeScript/NestJS**, **Rust**, **Go**, **Python**, **Docker**, **CI**, **SQL migrations**, and more.

## Install

```bash
# Project-level (only available in this repo)
npx skills add marcuspmd/smart-code-review

# Global (available in every project)
npx skills add marcuspmd/smart-code-review -g
```

---

## Usage

### Natural language (auto-activates)

Just describe what you want — the skill activates automatically:

```
review my changes
review my open changes
review this PR
review before merging
review against develop
review against main
review the last 3 commits
review what I staged
run code review and tests
```

### Slash command (explicit)

```
/code-review-agent
```

---

## Review Modes

The skill detects which surface to review based on your request:

| What you say | What gets reviewed |
|---|---|
| `review my changes` | Auto: staged → unstaged → branch ahead of base → last commit |
| `review against develop` | Diff of current branch vs `develop` |
| `review against main` | Diff of current branch vs `main` |
| `review this PR` / `review before merging` | Branch vs auto-detected base (main/master/develop) |
| `review the last 3 commits` | Last 3 commits on current branch |
| `review what I staged` | Staged changes only |

---

## What Happens During a Review

1. **Loads config** from `.ai/review.yml` (if present)
2. **Loads memory** from `.ai/review-memory.md` (if present)
3. **Detects the surface** — which diff to review
4. **Runs tools** — tests and linters if configured or requested
5. **Applies specialist passes** independently:
   - Security (always) — injection, authz, XSS, SSRF, secrets, crypto
   - Correctness — contracts, edge cases, error handling
   - Data — transactions, migrations, N+1, indexes
   - Performance — unbounded loops, memory pressure, caching
   - Architecture — DDD, layering, coupling
   - Tests — coverage gaps, brittle assertions
   - Operations — Docker, CI, env vars, deploy sequencing
   - A11y (if frontend) — WCAG 2.1 AA: keyboard, ARIA, contrast, semantic HTML
6. **Reflection pass** — challenges every finding: is it in the diff? concrete? severity accurate?
7. **Formats output** — P0 → P3 findings with file+line, risk, fix, and `APPROVE / REQUEST_CHANGES / COMMENT`

---

## Project Setup

### 1. Create `.ai/review.yml`

Tune the review for your stack:

```yaml
# TypeScript / NestJS
review:
  language: typescript
  frameworks: [nestjs]
  priorities: [security, correctness, architecture, tests]
  always_check: [authorization, sql_injection, ddd_layers]
  ignore:
    paths: [node_modules/**, dist/**]
  memory:
    file: .ai/review-memory.md
    auto_update: false
  tools:
    test_command: "npm test"
    static_analysis: [eslint, semgrep]
  custom_rules:
    - "Use z.uuid() instead of deprecated z.string().uuid()."
    - "Inject dependencies via constructor, not service locator."
```

```yaml
# PHP / Laravel
review:
  language: php
  frameworks: [laravel]
  tools:
    test_command: "./vendor/bin/pest"
    static_analysis: [phpstan, psalm]
  custom_rules:
    - "Controllers must not contain business logic — use Action classes."
```

See [`references/config-guide.md`](references/config-guide.md) for all options and per-stack presets.

### 2. Create `.ai/review-memory.md`

Persist project-specific knowledge across reviews:

```markdown
# Review Memory

## Architecture
- DDD boundaries enforced: Domain/ must not import from Infrastructure/.

## Recurring Issues
- Missing eager loading on Order::items causes N+1 in reports.

## Accepted Patterns
- Migrations split into schema + backfill steps for zero-downtime deploys.

## False Positives
- PHPStan flags mixed types in generated DTO classes — acceptable.
```

Memory is read before every review. The skill proposes new entries when it finds recurring patterns, and writes them when you confirm (or automatically if `auto_update: true`).

See [`references/memory-guide.md`](references/memory-guide.md) for format and management.

---

## Output Format

```
## Code Review — feature/auth-refactor

**Stack**: TypeScript / NestJS
**Scope**: 4 files changed, +187 / -23
**Tools**: eslint (0 errors), npm test (47 passed)
**Memory**: loaded (3 entries)

### Summary
...

### Findings

#### P1 — Refresh token exposed in error log
**File**: `src/auth/auth.service.ts:94`
**Risk**: Raw token logged in catch block — accessible to anyone with log access.
**Fix**: Remove `token` from logger context: `this.logger.error('Refresh failed', { userId })`.

### Recommendation
REQUEST_CHANGES — P1 findings must be resolved before merge.
```

Severity scale: `P0` (merge blocker) → `P1` (likely bug) → `P2` (architecture/test risk) → `P3` (low-risk improvement).

See [`references/output-format.md`](references/output-format.md) for the full template and examples.

---

## File Structure

```
code-review-agent/
├── SKILL.md
├── README.md
├── scripts/
│   ├── detect-surface.sh     # Detect review surface (auto/branch/PR/commits/staged)
│   ├── load-config.sh        # Load .ai/review.yml
│   ├── read-memory.sh        # Read .ai/review-memory.md
│   ├── write-memory.sh       # Append entries to memory sections
│   ├── run-tests.sh          # Auto-detect and run tests
│   └── run-linters.sh        # Auto-detect and run linters
└── references/
    ├── output-format.md      # Output template + examples
    ├── lens-security.md      # Security pass checklist
    ├── lens-a11y.md          # Accessibility pass checklist (WCAG 2.1 AA)
    ├── config-guide.md       # .ai/review.yml reference + per-stack presets
    ├── memory-guide.md       # Memory format and management
    ├── tools-guide.md        # Tool commands and integration rules
    └── review-system.md      # Specialist lens details and stack-specific prompts
```

## License

MIT
