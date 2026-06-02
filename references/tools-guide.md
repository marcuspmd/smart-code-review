# Tools Integration Guide

Configure and activate automated tools alongside code review to increase finding confidence.

## When Tools Run

Tools activate when:

1. The user explicitly asks ("review and run tests", "check with linters", "run phpstan")
2. `review.tools.test_command` is set in `.ai/review.yml`
3. A configured static analyzer is installed and the diff is relevant
4. High-confidence validation is available for the changed code (e.g., changed SQL, changed auth logic)

Expensive, stateful, or potentially destructive commands require explicit user request.

## Bundled Scripts

Two scripts auto-detect the stack and run the right tools:

```bash
# Detect and run tests
bash {baseDir}/scripts/run-tests.sh

# Detect and run linters / static analysis
bash {baseDir}/scripts/run-linters.sh

# Run tests filtered to a pattern
bash {baseDir}/scripts/run-tests.sh --filter "TestClassName"
```

## Test Frameworks

### JavaScript / TypeScript

```bash
# Jest / Vitest (via npm scripts)
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
npx eslint src/
npx eslint --ext .ts,.tsx src/
npx eslint changed-file.ts --format=compact
```

Configure in `eslint.config.js` or `.eslintrc.cjs`.

### PHPStan (PHP)

```bash
./vendor/bin/phpstan analyse --level=max src/
./vendor/bin/phpstan analyse --no-progress --error-format=table
```

Level guide: 0 = loose, 9 = strictest. Level 5+ recommended for new projects.

### Psalm (PHP)

```bash
./vendor/bin/psalm
./vendor/bin/psalm --show-info=true
./vendor/bin/psalm --taint-analysis          # Security taint tracking
```

### Cargo Clippy (Rust)

```bash
cargo clippy -- -D warnings
cargo clippy --all-targets -- -D warnings
```

### Go Vet + Staticcheck (Go)

```bash
go vet ./...
staticcheck ./...
```

### Semgrep (multi-language — security focus)

```bash
semgrep --config auto .
semgrep --config p/security-audit .
semgrep --config p/owasp-top-ten .
semgrep --config p/php .
semgrep --config p/typescript .
```

### Mypy / Ruff (Python)

```bash
mypy src/
ruff check .
ruff check --select=S .                      # Security rules only
```

## Git Operations Used During Review

```bash
# Identify the diff surface
git status --short
git diff --staged
git diff main...HEAD
git diff --name-only main...HEAD             # Changed files only

# Inspect history
git log --oneline -20
git log --follow -p -- src/auth/service.ts  # Full history for a file
git blame src/auth/service.ts

# Find affected test files
git diff --name-only main...HEAD | grep -E "(spec|test)\.(ts|php|go|rs|py)$"

# Show a specific commit
git show <sha>
git show <sha> --stat
```

## Inline Search (ripgrep)

```bash
# Find all callers of a changed function
rg "functionName" --type ts

# Find usages across languages
rg "ClassName" -l                            # List files only

# Find security-sensitive patterns
rg "eval\(" --type js
rg "query\(" -A 2 --type php                # Query calls + 2 lines of context

# Find tests related to a changed module
rg "AuthService" --type ts -l | grep -i spec
```

## Integrating Tool Output Into Findings

When a tool produces output:

1. **Map each finding to the diff** — is this line in the changed code or pre-existing?
2. **Verify actionability** — is it a real issue, a false positive, or a known exception (see memory)?
3. **Merge with lens findings** — one issue produces one finding even if multiple tools catch it.
4. **Label the source** — e.g., `[eslint]`, `[phpstan]`, `[cargo clippy]`, `[semgrep]`.
5. **Set severity from impact**, not from tool severity level.

Do **not** report pre-existing violations unless the diff makes them worse or directly caused them.

## Checking Tool Availability Before Running

```bash
# Safe pattern: check before running
command -v semgrep && semgrep --config auto . || echo "semgrep not installed"

# For project-local tools
[ -f vendor/bin/phpstan ] && ./vendor/bin/phpstan analyse src/ || echo "phpstan not available"
[ -f node_modules/.bin/eslint ] && npx eslint src/ || echo "eslint not available"
```

## Config Integration

Test command and static analysis tools can be specified in `.ai/review.yml`:

```yaml
review:
  tools:
    test_command: "./vendor/bin/pest --parallel"
    static_analysis:
      - phpstan
      - psalm
      - semgrep
```

When `test_command` is set, the skill runs it automatically on reviews that touch tested code. When a test fails, it is included as a `P1` finding.

## MCP Post-Review Actions

When `tools.mcps` is configured, the skill can perform post-review actions using MCP tools after producing the review report.

### Supported Actions

| Action type | Trigger | MCP tool pattern |
|---|---|---|
| `create_issue` | P0 findings + user confirmation | `mcp__<server>__create_issue` |
| `create_ticket` | P0 findings + user confirmation | `mcp__<server>__create_ticket` |
| `add_pr_comment` | After review output + user confirmation | `mcp__<server>__add_pr_comment` |

### MCP Tool Name Resolution

Tool names follow the `mcp__<server>__<action>` convention. Common examples:

| Server | create issue | PR comment |
|---|---|---|
| GitHub | `mcp__github__create_issue` | `mcp__github__add_pr_comment` |
| Jira | `mcp__jira__create_issue` | — |
| Linear | `mcp__linear__create_issue` | — |

If a tool name fails, try the `mcp__<server>__<server>_<action>` variant — some servers prefix the tool name with the server name.

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
