# Review Configuration Guide

Create `.ai/review.yml` to configure the code review workflow per project.

> **Upgrading from v1.x?** Read the [Migration & Upgrade Guide](migration-guide.md) to convert legacy configs to the standardized `tools.<name>` specification.

## Config Discovery Order

The skill looks for configuration strictly inside the `.ai/` directory (or user-level global defaults):

1. `~/.ai/review.yml` (or `~/.ai/review.yaml`) — global defaults (applied first; project config overrides)
2. `.ai/review.yml` — project-level config
3. `.ai/review.yaml` — project-level config (fallback)

> **Custom Paths**: Project configuration is always resolved from the `.ai/` folder by default. You can override this at any time by specifying an explicit path via the `--config <path>` flag when loading config.

When both global and project configs exist, they are merged. **Merge rules:**
- Scalar values (`language`, `auto_update`, etc.): project wins
- List values (`priorities`, `always_check`, `ignore.paths`, `custom_rules`, `extra_bash`, `extra_skills`): additive — global items first, then project items, deduplicated
- `tools.<name>`: project tool definition overrides global; commands, env, and parameters merged
- `tools.mcps`: additive; if same `server` in both, project entry takes precedence

If neither global nor project config is found, the review proceeds with stack auto-detection and default lenses.

## Optional Freeform Rules

In addition to the YAML config, you can place a `.ai/review-rules.md` file in the root of the repository. This file can contain bullet points, project-specific architecture rules, coding standards, or legacy constraints written in plain Markdown. The review agent will load and evaluate these rules during Step 1 and Step 5.

## Minimal Config

```yaml
review:
  language: typescript
  frameworks:
    - nestjs
```

## Full Config Reference

```yaml
review:
  # ── Stack ─────────────────────────────────────────────────────────────────
  language: typescript          # php | typescript | rust | go | python | java
  frameworks:
    - nestjs                    # laravel | express | fastapi | django | flask | ...

  # ── Review Focus ──────────────────────────────────────────────────────────
  priorities:                   # Ordered list of lenses (high → low)
    - security
    - correctness
    - performance
    - architecture
    - tests

  always_check:                 # Always run these regardless of priorities
    - sql_injection
    - authorization
    - n_plus_one
    - transaction_scope
    - ddd_layers
    - affected_tests

  # ── Ignore Rules ──────────────────────────────────────────────────────────
  ignore:
    paths:
      - vendor/**
      - node_modules/**
      - dist/**
      - coverage/**
      - "**/*.generated.ts"
    categories:
      - generated_code

  # ── Memory ────────────────────────────────────────────────────────────────
  memory:
    file: .ai/review-memory.md  # Path to memory file
    auto_update: false          # true = allow automatic memory writes after review

  # ── Tool Integration (Standardized v1.5.0 Specification) ──────────────────
  tools:
    test:
      enabled: true
      commands:
        run: "make test"                   # Main test suite command
      parameters:
        timeout: 600                       # Timeout in seconds
        min_coverage: 80                   # Minimum required test coverage %

    ruff:
      enabled: true                        # Active Python linter

    mypy:
      enabled: true                        # Active Python type checker

    # ── Advanced / Custom Tool: SonarQube (local, Docker) ─────────────────────
      enabled: true
      commands:
        run: "make sonar-scan"             # Main scan/analysis command (required)
        up: "make sonar-up"                # Provision/start container or server (optional)
        down: "make sonar-down"            # Teardown services after review (optional)
        health: "curl -f http://localhost:9000/api/system/status" # Readiness check before run (optional)
      env:
        SONAR_HOST_URL: "http://localhost:9000"
        SONAR_TOKEN: "${SONAR_TOKEN}"      # Prefer ${VAR} referencing local environment or .env
        # SECURITY NOTE: Never commit sensitive tokens/passwords directly in this file.
        # Prefer environment variable references (${VAR}) or let commands read from a .gitignored .env.
      parameters:
        project: "GIA---IEBT"              # Project identifier or componentKey
        branches: "main"                   # Base/target branch
        quality_gate: "default"            # Expected Quality Gate profile
        diff_scoped: true                  # Intersect issues with git diff lines (drops legacy debt)

    test:
      enabled: true
      commands:
        run: "make test"
      parameters:
        timeout: 600                       # Timeout in seconds
        min_coverage: 80                   # Minimum required test coverage %

    test-e2e:
      enabled: false                      # Run on demand: "review and run e2e"
      commands:
        up: "docker compose up -d test-db"
        run: "make test-e2e"
        down: "docker compose down"
      parameters:
        timeout: 900

    # ── Extra Bash Commands (optional) ───────────────────────────────────────
    # Additional bash command patterns to allow during the review.
    # Useful when installed globally and the project uses non-default tools.
    extra_bash:
      - "docker:*"
      - "kubectl:*"
      - "make:*"

    # ── Extra Peer Skills (optional) ──────────────────────────────────────────
    # Explicit file paths to additional skills to read for lens enrichment.
    extra_skills:
      - "~/.claude/skills/custom-audit/SKILL.md"

    # ── MCP Post-Review Actions (optional) ───────────────────────────────────
    # Configure which MCP servers to use for post-review actions.
    # server:    MCP server name
    # use_for:   create_issue | create_ticket | add_pr_comment
    # auto_post: if true, post without confirmation (default: false)
    mcps:
      - server: github
        use_for:
          - create_issue
          - add_pr_comment
        auto_post: false
      - server: jira
        use_for:
          - create_ticket
        auto_post: false

  # ── Custom Rules ──────────────────────────────────────────────────────────
  custom_rules:
    - "Never use repositories inside entities."
    - "Actions must validate permissions before mutating state."
    - "All POST endpoints must be idempotent or accept an Idempotency-Key header."
```

## Standardized Tool Specification (`tools.<name>`)

Any analysis tool, test runner, scanner, or local service can be registered under `tools.<name>` using this standardized structure. The AI reviewer understands this schema natively and orchestrates execution without custom code:

### 1. Lifecycle Commands (`commands`)

| Command Key | Purpose | Required | Example |
|---|---|---|---|
| `run` | Primary analysis, test, or scan command | **Yes** | `"make sonar-scan"`, `"pytest"`, `"npm test"` |
| `up` | Starts or provisions required daemon/DB | No | `"make sonar-up"`, `"docker compose up -d db"` |
| `health` | Readiness probe checked before running | No | `"curl -f http://localhost:9000/api/system/status"` |
| `down` | Shuts down background containers/services | No | `"make sonar-down"`, `"docker compose down"` |
| `clean` | Cleans temporary cache, build, or coverage files | No | `"make clean"` |

**Execution Logic**:
1. If `commands.health` is defined, the agent runs it first.
2. If health check succeeds, the agent skips `commands.up` (idempotent).
3. If health check fails or endpoint is unreachable, the agent executes `commands.up`, waits for readiness, and then proceeds.
4. The agent executes `commands.run`.
5. If the user explicitly asks to teardown services after the review, the agent runs `commands.down`.

### 2. Environment Variables (`env`)

Defines environment variables required during execution:

```yaml
env:
  SONAR_HOST_URL: "http://localhost:9000"
  SONAR_TOKEN: "${SONAR_TOKEN}"
```

> [!CAUTION] Security Warning: Credential Exposure
> Never commit real secrets, API keys, or database passwords directly into `.ai/review.yml` (which is tracked in git).
> - **Preferred**: Use `${VAR_NAME}` notation so the value is resolved from the local developer environment.
> - **Alternative**: Rely on a local `.env` file that is already ignored by `.gitignore`.

### 3. Parameters (`parameters`)

Provides semantic hints and controls to the AI reviewer:

| Parameter | Type | Purpose | Example |
|---|---|---|---|
| `diff_scoped` | `boolean` | When `true`, filters findings to only files & lines touched in the review's `git diff` | `true` |
| `project` | `string` | Target project or component key | `"GIA---IEBT"` |
| `branches` | `string` | Base or target branch | `"main"` |
| `quality_gate`| `string` | Target Quality Gate profile name | `"default"` |
| `timeout` | `integer` | Maximum execution time in seconds | `600` |
| `min_coverage`| `integer` | Minimum expected test coverage % | `80` |

---

## Per-Stack Presets

### Python / FastAPI or Django (with SonarQube & Pytest)

```yaml
review:
  language: python
  frameworks: [fastapi]
  priorities: [security, correctness, performance, data, architecture, tests]
  always_check: [sql_injection, authorization, n_plus_one]
  ignore:
    paths: [.venv/**, venv/**, "__pycache__/**", "*.egg-info/**"]
    categories: [generated_code]
  memory:
    file: .ai/review-memory.md
    auto_update: false
  tools:
    test:
      enabled: true
      commands:
        run: "make test"
      parameters:
        timeout: 600
        min_coverage: 80
    ruff:
      enabled: true
    mypy:
      enabled: true
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
  custom_rules:
    - "Async route handlers must never call blocking synchronous functions."
    - "Always use timezone-aware datetimes (datetime.now(timezone.utc))."
```

### Go

```yaml
review:
  language: go
  priorities: [correctness, security, performance, architecture, tests]
  always_check: [error_handling, goroutine_leaks, context_propagation, race_conditions]
  ignore:
    paths: [vendor/**, "*.pb.go", "*_generated.go"]
    categories: [generated_code]
  memory:
    file: .ai/review-memory.md
    auto_update: false
  tools:
    test:
      enabled: true
      commands:
        run: "go test -race ./..."
    govet:
      enabled: true
    staticcheck:
      enabled: true
  custom_rules:
    - "Never ignore errors returned by functions; handle or return explicitly."
    - "Ensure context.Context is accepted as the first parameter for all I/O or network functions."
    - "Mutex locks must be immediately followed by defer mu.Unlock()."
```

### PHP / Laravel

```yaml
review:
  language: php
  frameworks: [laravel]
  priorities: [security, correctness, data, performance, architecture, tests]
  always_check: [sql_injection, authorization, n_plus_one, transaction_scope]
  ignore:
    paths: [vendor/**, storage/**, bootstrap/cache/**]
  memory:
    file: .ai/review-memory.md
    auto_update: false
  tools:
    test:
      enabled: true
      commands:
        run: "./vendor/bin/pest"
    phpstan:
      enabled: true
    psalm:
      enabled: true
  custom_rules:
    - "Controllers must not contain business logic — use Action or Service classes."
    - "Avoid nested foreach loops unless data volume is explicitly bounded."
```

### TypeScript / NestJS

```yaml
review:
  language: typescript
  frameworks: [nestjs]
  priorities: [security, correctness, architecture, performance, tests]
  always_check: [authorization, sql_injection, ddd_layers]
  ignore:
    paths: [node_modules/**, dist/**, "**/*.spec.ts"]
    categories: [generated_code]
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
    - "Use z.uuid() instead of z.string().uuid() (deprecated in Zod v4)."
    - "Inject dependencies via constructor, not via service locator."
```

### Rust

```yaml
review:
  language: rust
  priorities: [correctness, security, performance]
  always_check: [unsafe_blocks, error_propagation, lock_scope]
  memory:
    file: .ai/review-memory.md
    auto_update: false
  tools:
    test:
      enabled: true
      commands:
        run: "cargo test"
    clippy:
      enabled: true
```

### Docker / CI Only

```yaml
review:
  language: dockerfile
  priorities: [security, operations]
  always_check: [image_pinning, secrets, permissions, deploy_ordering, health_checks]
```
