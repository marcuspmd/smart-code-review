# Migration & Upgrade Guide (v1.5.0)

This guide walks you through upgrading your `.ai/review.yml` to the **Standardized Tool Specification (v1.5.0)**.

---

## What Changed in v1.5.0?

In previous versions, tools used flat, rigid keys (`test_command` string and `static_analysis` list of names). This had two major drawbacks:
1. Tools with setup/daemon requirements (like local SonarQube, dockerized databases, or E2E suites) required custom bash scripts.
2. Tool execution couldn't specify lifecycle hooks (`up`, `down`, `health`), timeouts, or diff-scoping controls.

In **v1.5.0**, backwards compatibility for legacy flat keys has been removed in favor of a clean, canonical **Lifecycle Specification** under `tools.<tool_name>`.

---

## Quick Conversion Cheat Sheet

| Legacy Syntax (v1.x) | Standardized Syntax (v1.5.0) |
|---|---|
| `test_command: "make test"` | `tools.test: { enabled: true, commands: { run: "make test" } }` |
| `static_analysis: [ruff, mypy]` | `tools.ruff: { enabled: true }`<br>`tools.mypy: { enabled: true }` |
| `static_analysis: [eslint]` | `tools.eslint: { enabled: true, commands: { run: "npx eslint src/" } }` |
| Ad-hoc Sonar scripts | `tools.sonar: { enabled: true, commands: { up: "...", run: "..." }, ... }` |

---

## Step-by-Step Upgrade Tutorial

### Step 1: Update Test Runners (`tools.test`)

#### Before (Legacy):
```yaml
review:
  tools:
    test_command: "pytest --cov=src"
```

#### After (v1.5.0):
```yaml
review:
  tools:
    test:
      enabled: true
      commands:
        run: "pytest --cov=src"
      parameters:
        timeout: 300       # Optional: timeout in seconds
        min_coverage: 80   # Optional: alert if coverage drops below threshold
```

---

### Step 2: Update Linters and Static Analyzers

Instead of a flat list of strings, each analyzer is declared as a named object under `tools:` with `enabled: true`. You can optionally specify a custom `commands.run` if you want flags different from the project default.

#### Before (Legacy):
```yaml
review:
  tools:
    static_analysis:
      - eslint
      - semgrep
```

#### After (v1.5.0):
```yaml
review:
  tools:
    eslint:
      enabled: true
      commands:
        run: "npx eslint src/"    # Optional: override default detection
    semgrep:
      enabled: true
```

---

### Step 3: Configure On-Demand / Advanced Tools (SonarQube, E2E, Docker)

For tools that require background services or diff-scoping (like SonarQube Community Edition):

#### Full v1.5.0 Specification:
```yaml
review:
  tools:
    sonar:
      enabled: true
      commands:
        health: "curl -f http://localhost:9000/api/system/status" # Checked first (optional)
        up: "make sonar-up"                                       # Runs if health fails (optional)
        run: "make sonar-scan"                                    # Main scan (required)
        down: "make sonar-down"                                   # Teardown after review (optional)
      env:
        SONAR_HOST_URL: "http://localhost:9000"
        SONAR_TOKEN: "${SONAR_TOKEN}"                             # Resolved from env or .env
      parameters:
        project: "MY_PROJECT_KEY"
        diff_scoped: true                                         # Intersects issues with review git diff
```

---

## Before & After Comparison: Complete Examples

### Example 1: TypeScript / NestJS

#### Before (v1.4.x):
```yaml
review:
  language: typescript
  frameworks: [nestjs]
  tools:
    test_command: "npm test"
    static_analysis:
      - eslint
      - semgrep
```

#### After (v1.5.0):
```yaml
review:
  language: typescript
  frameworks: [nestjs]
  tools:
    test:
      enabled: true
      commands:
        run: "npm test"
      parameters:
        timeout: 300
    eslint:
      enabled: true
    semgrep:
      enabled: true
```

---

### Example 2: Python / FastAPI + SonarQube

#### Before (v1.4.x):
```yaml
review:
  language: python
  frameworks: [fastapi]
  tools:
    test_command: "make test"
    static_analysis:
      - ruff
      - mypy
    sonar:
      enabled: true
      up_command: "make sonar-up"
      scan_command: "make sonar-scan"
      host_url: "http://localhost:9000"
      project_key: "GIA---IEBT"
      diff_scoped: true
```

#### After (v1.5.0):
```yaml
review:
  language: python
  frameworks: [fastapi]
  tools:
    test:
      enabled: true
      commands:
        run: "make test"
      parameters:
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
```

---

### Example 3: PHP / Laravel

#### Before (v1.4.x):
```yaml
review:
  language: php
  frameworks: [laravel]
  tools:
    test_command: "./vendor/bin/pest"
    static_analysis:
      - phpstan
```

#### After (v1.5.0):
```yaml
review:
  language: php
  frameworks: [laravel]
  tools:
    test:
      enabled: true
      commands:
        run: "./vendor/bin/pest"
    phpstan:
      enabled: true
```

---

## Verifying Your Migration

After updating your `.ai/review.yml`, verify that the skill loads and understands the new configuration:

```bash
# 1. Verify config parsing
bash scripts/load-config.sh

# 2. Test running configured tests
bash scripts/run-tests.sh

# 3. Test running configured linters
bash scripts/run-linters.sh
```

If any tool is misconfigured, `load-config.sh` and the runner scripts will clearly display the detected state and commands.

