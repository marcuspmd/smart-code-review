# Tools Integration Guide

Configure and activate automated tools alongside code review to increase finding confidence.

## When Tools Run

Tools activate when:

1. The user explicitly asks ("review and run tests", "check with linters", "run phpstan", "run sonar")
2. `review.tools.test_command` is set in `.ai/review.yml`
3. A configured static analyzer is installed and the diff is relevant
4. `review.tools.sonar` is configured and enabled in `.ai/review.yml`
5. High-confidence validation is available for the changed code (e.g., changed SQL, changed auth logic)

Expensive, stateful, or potentially destructive commands require explicit user request.

## Bundled Scripts

Scripts auto-detect the stack and run the right tools:

```bash
# Detect and run tests
bash {baseDir}/scripts/run-tests.sh

# Detect and run linters / static analysis (scans project or filtered files)
bash {baseDir}/scripts/run-linters.sh

# Run linters targeted to specific changed files
bash {baseDir}/scripts/run-linters.sh --files "src/auth/service.ts,src/auth/dto.ts"

# Run tests filtered to a pattern
bash {baseDir}/scripts/run-tests.sh --filter "TestClassName"

# Run SonarQube with diff-scoping (drops pre-existing debt outside review diff)
bash {baseDir}/scripts/run-sonar.sh
```

## Test Frameworks

### JavaScript / TypeScript

```bash
# Jest / Vitest (via npm, pnpm, yarn, or bun scripts)
npm test
npm test -- --testPathPattern="src/auth"

# Scoped to changed files
CHANGED=$(git diff --name-only HEAD~1 HEAD | grep -E "\.(ts|tsx)$" | tr '\n' ' ')
[ -n "$CHANGED" ] && npx jest $CHANGED

# Custom test scripts from package.json
npm run test:unit
npm run test:integration
```

### PHP

```bash
# Pest (preferred)
./vendor/bin/pest
./vendor/bin/pest --filter="AuthServiceTest"

# PHPUnit
./vendor/bin/phpunit
./vendor/bin/phpunit --filter="AuthServiceTest"
./vendor/bin/phpunit tests/Unit/
```

### Rust

```bash
cargo test
cargo test auth                        # filter by name
cargo test --package my-crate
```

### Go

```bash
go test ./...
go test ./pkg/auth/... -run TestLogin
go test -v -race ./...
```

### Python

```bash
pytest
pytest tests/unit/
pytest -k "test_auth"
pytest --cov=src tests/
```

## Static Analysis Tools

### ESLint (JavaScript / TypeScript)

```bash
# Flat config (ESLint v9+)
npx eslint src/
npx eslint changed-file.ts

# Legacy config (.eslintrc.*)
npx eslint --ext .ts,.tsx src/
```

Configure in `eslint.config.js`, `eslint.config.mjs`, or legacy `.eslintrc.cjs`.

### PHPStan (PHP)

```bash
./vendor/bin/phpstan analyse --level=8 src/
./vendor/bin/phpstan analyse --error-format=table src/
```

Configure in `phpstan.neon` or `phpstan.neon.dist`.

### Psalm (PHP)

```bash
./vendor/bin/psalm
./vendor/bin/psalm --show-info=true
./vendor/bin/psalm path/to/file.php
```

Configure in `psalm.xml`.

### Cargo Clippy (Rust)

```bash
cargo clippy -- -D warnings
cargo clippy --all-targets --all-features
```

### Go Vet & Staticcheck (Go)

```bash
go vet ./...
staticcheck ./...
```

### Ruff (Python)

```bash
ruff check .
ruff check --fix .
ruff check path/to/file.py
```

### Mypy (Python)

```bash
mypy src/
mypy --strict src/
```

### Semgrep (Multi-language Security)

```bash
semgrep --config auto .
semgrep --config "p/security-audit" --config "p/owasp-top-ten" .
semgrep --config auto path/to/changed-file.py
```

Runs offline; fast; catches common CVE patterns and OWASP Top 10 vulnerabilities.

---

## SonarQube & SonarCloud Integration

SonarQube and SonarCloud provide enterprise-grade static analysis covering code quality, maintainability, test coverage, and security vulnerabilities across 30+ programming languages.

### 1. The Community Edition Challenge: Why `diff_scoped: true` is Critical

- **Community Edition limitation**: SonarQube Community Edition does not support branch or PR analysis (`sonar.branch.*` and `sonar.pullrequest.*` are gated behind paid Developer Edition licenses).
- **The False-Positive Trap**: The local scan runs across the entire workspace filesystem (including uncommitted, staged, and untracked files). The server evaluates "New Code" against a fixed server-side leak period (e.g. 30 days or version bump), **NOT** the specific commits or working tree diff under review.
- **The Solution**: With `diff_scoped: true` in `.ai/review.yml` (executed via `scripts/run-sonar.sh`):
  1. The script triggers your scan (`make sonar-scan` or `sonar-scanner`).
  2. It queries open issues from the Sonar REST API:
     ```bash
     curl -s -u "$SONAR_TOKEN:" "http://localhost:9000/api/issues/search?componentKeys=MY_PROJECT&resolved=false&ps=500"
     ```
  3. It extracts each issue's `component` (file path) and `line`.
  4. It intersects those issues with the exact files and lines touched by the review's `git diff` (from Step 2).
  5. **Result**: Only issues introduced or modified in the current diff are reported. All pre-existing legacy issues outside the diff are dropped as existing technical debt.

### 2. Configuration in `.ai/review.yml`

```yaml
review:
  tools:
    test_command: "make test"
    static_analysis:
      - ruff
      - mypy

    # ── Standardized Tool Specification (e.g. SonarQube) ─────────────────────
    sonar:
      enabled: true
      commands:
        up: "make sonar-up"                # Provision/start containers if needed (optional)
        run: "make sonar-scan"             # Primary analysis command (required)
        down: "make sonar-down"            # Teardown services after review (optional)
        health: "curl -f http://localhost:9000/api/system/status" # Readiness check before run (optional)
      env:
        SONAR_HOST_URL: "http://localhost:9000"
        SONAR_TOKEN: "${SONAR_TOKEN}"      # Read from environment or local .env
      parameters:
        project: "GIA---IEBT"              # Target project key
        diff_scoped: true                  # Intersect issues with git diff lines (drops legacy debt)
```

### 3. Spinning up a Local SonarQube Instance (Docker)

To run a lightweight local SonarQube server for local development:

```bash
# Start SonarQube Community Edition in the background
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community

# Check logs to see when SonarQube is up (usually takes 30-60s)
docker logs -f sonarqube
```

- Web UI opens at: `http://localhost:9000`
- Default login: `admin` / `admin` (prompts for new password on first login)
- Generate a user token at: `User Profile > Security > Generate Tokens` (e.g., `sqp_xxxxxxxxxxxx`).
- Save the token to your local `.env` file: `SONAR_TOKEN=sqp_xxxxxxxxxxxx`.

### 4. Project Configuration (`sonar-project.properties`)

Create `sonar-project.properties` in your repository root:

```properties
# Project identification
sonar.projectKey=MY_PROJECT_KEY
sonar.projectName=My Project
sonar.projectVersion=1.0

# Paths
sonar.sources=src
sonar.tests=tests
sonar.exclusions=**/node_modules/**,**/vendor/**,**/dist/**,**/*.spec.ts,**/coverage/**

# SonarQube Server URL (or https://sonarcloud.io)
sonar.host.url=http://localhost:9000

# Wait for Quality Gate calculation so scanner exits non-zero if Gate fails
sonar.qualitygate.wait=true

# Source encoding
sonar.sourceEncoding=UTF-8
```

### 5. Running the Analysis (Agent-Orchestrated via Standard Lifecycle)

No custom runner script is required. The AI agent reads the standardized configuration from `.ai/review.yml` and orchestrates the steps directly:
1. **Health Check**: Executes `commands.health` (e.g. `curl -f http://localhost:9000/api/system/status`). If unhealthy or offline, executes `commands.up` (e.g. `make sonar-up`) and awaits readiness.
2. **Runs Scan**: Executes `commands.run` (e.g. `make sonar-scan`).
3. **Pulls & Filters Issues**: Resolves `env.SONAR_TOKEN`, queries the Sonar API (`/api/issues/search`), and in-context filters findings to only those on lines touched in the review's `git diff` (if `parameters.diff_scoped: true`).
4. **Applies Rubric**: Formats findings according to P0–P3 severity without manual intervention.

### 6. Interpreting Sonar Findings in Code Reviews

When reviewing code analyzed by Sonar, map its issue types and severities to the review rubric:

| Sonar Issue Type & Severity | Review Impact | Action |
|---|---|---|
| **Blocker / Critical Bug** | **P0** or **P1** | Blocker: potential crash, data loss, or broken control flow. Require fix before merge. |
| **Vulnerability (High/Critical)** | **P0** or **P1** | Security breach, SQLi, XSS, or hardcoded credential. Must be resolved. |
| **Security Hotspot (To Review)** | **P1** | Human inspection required (e.g. crypto algorithm, CORS, file access). |
| **Major Code Smell** | **P2** | Maintainability regression, high cyclomatic complexity, or memory inefficiency. |
| **Minor / Info Code Smell** | **P3** or drop | Minor formatting, unused imports, or style nit. Drop if trivial. |
| **Failed Quality Gate** | **REQUEST_CHANGES** | Review fails if coverage dropped below threshold or new blocker bugs were introduced. |

---

## Integration Rules

### 1. Tools Inform, Humans Decide

Do not blindly copy a linter or Sonar error into the review report.
- Verify the line was changed in this diff (static analysis often reports on pre-existing code).
- Assess whether it actually matters in context.
- If it's a known false positive (check `.ai/review-memory.md`), discard it.
- If it's a style nit with no functional impact, either drop it or place it at P3.

### 2. Failure Severity Summary

| Tool result | Review impact |
|---|---|
| Failing unit test on changed code | **P1** finding: "Test failure: [test name] fails on this change" |
| PHPStan/Mypy type error on changed line | **P1** or **P2** depending on runtime risk |
| Semgrep high-confidence security finding | **P0** or **P1** finding |
| SonarQube Blocker Bug / Vulnerability | **P0** or **P1** finding |
| ESLint unused variable | **P3** finding or drop if trivial |
| Pre-existing tool error on untouched line | **Discard** — not introduced by this diff |

### 3. Graceful Degradation

If a tool is not installed or fails to run:
- Do not fail the review.
- Note the missing tool in the review output metadata: `Tools: sonar (not running/configured)`.
- Suggest running it if relevant to the project stack.

## Config Integration (Standardized v1.5.0 Format)

Tools are declared in `.ai/review.yml` under `tools.<name>` with their commands and parameters:

```yaml
review:
  tools:
    test:
      enabled: true
      commands:
        run: "./vendor/bin/pest --parallel"
      parameters:
        timeout: 300
    phpstan:
      enabled: true
    psalm:
      enabled: true
    semgrep:
      enabled: true
```

When `tools.test.enabled: true` and `commands.run` is defined, the skill runs it automatically on reviews that touch tested code. When a test fails, it is included as a `P1` finding.

> See [`references/migration-guide.md`](migration-guide.md) for upgrading legacy configs.

## MCP Post-Review Actions

When `tools.mcps` is configured, the skill can perform post-review actions using MCP tools after producing the review report.

### Supported Actions

| Action type | Trigger | MCP tool action |
|---|---|---|
| `create_issue` | P0 findings + user confirmation | Create issue/task on tracker |
| `create_ticket` | P0 findings + user confirmation | Create ticket on issue tracker |
| `add_pr_comment` | After review output + user confirmation | Post review markdown as comment |

### MCP Tool Name Resolution

Tool names depend on the host agent environment:

- **Claude Code**: Uses double underscore format: `mcp__<server>__<action>` (e.g., `mcp__github__create_issue`, `mcp__github__add_pr_comment`, `mcp__jira__create_issue`).
- **Antigravity / Universal MCP**: Uses single underscore format `mcp_<server>_<action>` (e.g., `mcp_github_create_issue`) or invokes registered tool directly by server name.

Common examples:

| Server | Claude Code pattern | Antigravity / Universal pattern |
|---|---|---|
| GitHub | `mcp__github__create_issue` | `mcp_github_create_issue` |
| GitHub PR Comment | `mcp__github__add_pr_comment` | `mcp_github_add_pr_comment` |
| Jira | `mcp__jira__create_issue` | `mcp_jira_create_issue` |
| Linear | `mcp__linear__create_issue` | `mcp_linear_create_issue` |

If a tool call fails or cannot be resolved, graceful degradation ensures the review report remains unaffected.

### Config

```yaml
review:
  tools:
    mcps:
      - server: github
        use_for: [create_issue, add_pr_comment]
        auto_post: false   # true = post without confirmation (default: false)
      - server: jira
        use_for: [create_ticket]
        auto_post: false
```

**`auto_post: false`** (default): the skill asks before executing any MCP action.  
**`auto_post: true`**: executes immediately after the review without prompting.

MCP failures are non-blocking — the review report is always the primary deliverable.
