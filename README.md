# code-review-agent

Context-aware AI code review with persistent memory, configurable rules, specialist lenses, and automated tool integration.

## What It Does

Runs a structured code review by loading project context, identifying the diff surface, applying focused specialist lenses, running tests and linters when useful, and producing prioritized findings (P0–P3).

Works with: **PHP/Laravel**, **TypeScript/NestJS**, **Rust**, **Go**, **Python**, **Docker**, **CI**, **SQL migrations**, and more.

## Install

```bash
npx skills add marcusmazzon/code-review-agent
```

## Usage

Invoke automatically or explicitly:

```
/code-review-agent
/code-review-agent review feature/auth-refactor
/code-review-agent review and run tests
```

Or just describe what you want — the skill activates when you mention reviewing PRs, diffs, branches, or changes.

## Features

### Specialist Lenses

Every review applies focused lenses matched to the changed files:

| Lens | What It Checks |
|---|---|
| **Correctness** | Broken contracts, edge cases, error handling, state transitions |
| **Security** | AuthZ/AuthN, injection, XSS, SSRF, secrets, path traversal |
| **Data** | Transaction scope, migrations, indexes, constraints, rollback paths |
| **Performance** | N+1 queries, unbounded loops, memory pressure, caching |
| **Architecture** | Layering, DDD boundaries, dependency direction |
| **Tests** | Missing tests, brittle assertions, coverage gaps |
| **Operations** | Docker, CI, env vars, observability, deploy sequencing |

### Project Configuration

Create `.ai/review.yml` to tune the review for your project:

```yaml
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

See `references/config-guide.md` for the full reference and per-stack presets.

### Persistent Memory

Create `.ai/review-memory.md` to store project-specific review knowledge:

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

The skill reads memory before each review to raise sensitivity on known issues and suppress known false positives. See `references/memory-guide.md` for format details.

### Automated Tools

The skill can run tests and linters alongside the review:

```bash
# Auto-detect and run tests (Jest, Pest, PHPUnit, cargo test, go test, pytest)
bash scripts/run-tests.sh

# Auto-detect and run linters (ESLint, PHPStan, Psalm, cargo clippy, ruff, semgrep)
bash scripts/run-linters.sh
```

Tools activate automatically when configured in `.ai/review.yml` or when the user explicitly asks. See `references/tools-guide.md` for per-tool commands and integration rules.

## File Structure

```
code-review-agent/
├── SKILL.md                        # Skill instructions and frontmatter
├── README.md                       # This file
├── scripts/
│   ├── run-tests.sh                # Auto-detect and run tests
│   └── run-linters.sh              # Auto-detect and run linters
└── references/
    ├── config-guide.md             # .ai/review.yml reference + per-stack presets
    ├── memory-guide.md             # Memory format and management
    ├── tools-guide.md              # Tool commands and integration rules
    └── review-system.md            # Specialist lens details and stack-specific prompts
```

## Findings Format

Findings are ordered by severity:

- `P0` — data loss, security breach, production outage, hard merge blocker
- `P1` — likely bug, serious security/performance regression, broken core workflow
- `P2` — meaningful maintainability, architecture, test, or edge-case risk
- `P3` — low-risk improvement, only noted on otherwise clean reviews

Each finding includes: severity, file + line reference, concrete risk, and a suggested fix or validation path.

## License

MIT
