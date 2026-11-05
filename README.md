# smart-code-review

Context-aware AI code review with persistent memory, configurable rules, specialist lenses, and automated tool integration.

Works with: **PHP/Laravel**, **TypeScript/NestJS**, **Python (FastAPI/Django)**, **Go**, **Rust**, **Docker**, **CI/CD**, **SQL migrations**, **SonarQube / SonarCloud**, and more.

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
review my changes and run sonarqube
init review
install review hooks
```

### Slash command (explicit)

```
/smart-code-review
/smart-code-review init
# or legacy alias:
/code-review-agent
/code-review-agent init
```

---

## Quick Initialization

Initialize code review configuration, memory, and rules interactively:

```bash
# Interactive wizard
bash scripts/init.sh

# Fast setup with defaults
bash scripts/init.sh --defaults

# Install Git pre-commit & pre-push review hooks
bash scripts/install-hooks.sh
```

---

## Review Modes

The skill detects which surface to review based on your request:

| What you say | What gets reviewed |
|---|---|
| `review my changes` | Auto: staged → unstaged → untracked → branch ahead of base → last commit |
| `review against develop` | Diff of current branch vs `develop` |
| `review against main` | Diff of current branch vs `main` |
| `review this PR` / `review before merging` | Branch vs auto-detected base (main/master/develop) |
| `review the last 3 commits` | Last 3 commits on current branch |
| `review what I staged` | Staged changes only |

---

## What Happens During a Review

1. **Loads config** — merges global (`~/.ai/review.yml`) with project (`.ai/review.yml` or `.ai/review.yaml`).
2. **Loads memory** from `.ai/review-memory.md` and repository guidelines from `.ai/review-rules.md` (if present).
3. **Discovers peer skills** — reads other installed skills for checklist enrichment.
4. **Detects the surface** — resolves exact git diff with lockfile exclusions to preserve context window.
5. **Runs tools** — executes relevant linters (ESLint Flat/Legacy, Ruff, Mypy, PHPStan, Go Vet, Semgrep, SonarQube Scanner) and test suites when configured.
6. **Applies specialist passes** independently:
   - **Security** (`references/lens-security.md`) — auth, injection, XSS, SSRF, secrets, crypto
   - **Data & Migrations** (`references/lens-data.md`) — locks, zero-downtime expand/contract, N+1, indexes
   - **Correctness & Concurrency** (`references/lens-correctness.md`) — race conditions, deadlocks, error swallowing
   - **Performance** (`references/lens-performance.md`) — unbounded loops, memory pressure, cache stampede
   - **Architecture** (`references/lens-architecture.md`) — DDD boundaries, layering, coupling
   - **Tests** — missing coverage for changed logic, assertion efficacy
   - **Operations** — Docker image pinning, CI secrets, deployment ordering
   - **A11y** (`references/lens-a11y.md`) — WCAG 2.1 AA: keyboard nav, ARIA, focus, contrast
7. **Reflection / Critic pass** — verifies findings are in the diff, verifies exact line numbers in target files, deduplicates and adjusts severity.
8. **Formats output** — P0 → P3 findings with file+line, risk, concrete fix, and `APPROVE / REQUEST_CHANGES / COMMENT`.
9. **Optional MCP post-actions** — creates issues/tickets for P0 findings or posts review comments to GitHub/Jira/Linear.

---

## SonarQube & SonarCloud Integration

Run enterprise-grade static analysis and quality gates locally or in CI:

```bash
# Run local SonarQube server via Docker
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community

# Execute scan with sonar-scanner CLI, NPX, or Docker:
sonar-scanner -Dsonar.token="YOUR_TOKEN"
# or without installing scanner:
docker run --rm --network="host" -v "${PWD}:/usr/src" sonarsource/sonar-scanner-cli
```

Findings map directly to review severity: Blocker/Critical Bugs → **P0/P1**, Security Hotspots → **P1**, Major Smells → **P2**.  
See [`references/tools-guide.md`](references/tools-guide.md) for full setup instructions and `sonar-project.properties` template.

---

## Memory Management: Add, Edit, Remove & Compact

Keep review memory clean, accurate, and bloat-free over time:

```bash
# Add a new rule or pattern
bash scripts/manage-memory.sh --add --section "Architecture" --entry "Domain/ must not import from Infrastructure/"

# Edit or replace an outdated rule
bash scripts/manage-memory.sh --replace "old pattern" --with "new pattern"

# Remove an obsolete or deleted convention
bash scripts/manage-memory.sh --remove "old pattern"

# Check stats (entry count per section)
bash scripts/manage-memory.sh --stats

# Compact and deduplicate entries
bash scripts/manage-memory.sh --compact
```

See [`references/memory-guide.md`](references/memory-guide.md) for guidelines on when to prune and synthesize entries.

---

## Project Setup

### 1. Create `.ai/review.yml`

Tune the review for your stack:

```yaml
# TypeScript / NestJS (Standardized Tools v1.5.0)
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
    test:
      enabled: true
      commands:
        run: "npm test"
    eslint:
      enabled: true
    semgrep:
      enabled: true
  custom_rules:
    - "Use z.uuid() instead of deprecated z.string().uuid()."
    - "Inject dependencies via constructor, not service locator."
```

```yaml
# Python / FastAPI with Standardized Tools (Pytest, Ruff, SonarQube)
review:
  language: python
  frameworks: [fastapi]
  priorities: [security, correctness, performance, data, architecture, tests]
  always_check: [sql_injection, authorization, n_plus_one]
  memory:
    file: .ai/review-memory.md
    auto_update: false
  tools:
    static_analysis: [ruff, mypy]
    sonar:
      enabled: true
      commands:
        up: "make sonar-up"
        run: "make sonar-scan"
        down: "make sonar-down"
        health: "curl -f http://localhost:9000/api/system/status"
      env:
        SONAR_HOST_URL: "http://localhost:9000"
        SONAR_TOKEN: "${SONAR_TOKEN}"
      parameters:
        project: "GIA---IEBT"
        diff_scoped: true
    test:
      enabled: true
      commands:
        run: "make test"
      parameters:
        min_coverage: 80
  custom_rules:
    - "Async route handlers must never call blocking synchronous functions."
    - "Always use timezone-aware datetimes (datetime.now(timezone.utc))."
```

See [`references/config-guide.md`](references/config-guide.md) for all options and presets (Go, Rust, Docker, PHP), and [`references/migration-guide.md`](references/migration-guide.md) for upgrading from v1.x configs.

---

## File Structure

```
smart-code-review/
├── SKILL.md
├── README.md
├── scripts/
│   ├── detect-surface.sh     # Detect review surface (auto/branch/PR/commits/staged/untracked)
│   ├── discover-skills.sh    # Discover peer skills across project and global paths
│   ├── load-config.sh        # Merge global (~/.ai) and project (.ai) review configs
│   ├── read-memory.sh        # Read .ai/review-memory.md
│   ├── write-memory.sh       # Add entries to memory (delegates to manage-memory.sh)
│   ├── manage-memory.sh      # Full memory lifecycle: add, replace/edit, remove, stats, compact
│   ├── run-tests.sh          # Auto-detect test runner (npm/pnpm/yarn/bun/pest/pytest/go/cargo)
│   └── run-linters.sh        # Run linters (ESLint, Ruff, Mypy, PHPStan, Go Vet, Semgrep)
└── references/
    ├── output-format.md      # Output template + examples
    ├── lens-security.md      # Security pass checklist (Python, Go, Rust, PHP, TS, SQL)
    ├── lens-data.md          # Data, SQL & zero-downtime migrations checklist
    ├── lens-correctness.md   # Correctness, concurrency & edge cases checklist
    ├── lens-performance.md   # Performance, memory leaks & query optimization checklist
    ├── lens-architecture.md  # Architecture, DDD & layering checklist
    ├── lens-a11y.md          # Accessibility pass checklist (WCAG 2.1 AA)
    ├── config-guide.md       # .ai/review.yml reference + per-stack presets
    ├── migration-guide.md    # Upgrade and migration guide for v1.5.0 standardized tools
    ├── memory-guide.md       # Memory lifecycle, quality, and compaction guide
    ├── tools-guide.md        # Tools, SonarQube/SonarCloud Docker setup, and MCP rules
    └── review-system.md      # Specialist lens details and stack-specific prompts
```

## License

MIT
