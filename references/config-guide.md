# Review Configuration Guide

Create `.ai/review.yml` to configure the code review workflow per project.

## Config Discovery Order

The skill looks for config in this order:

1. `~/.ai/review.yml` — global defaults (applied first; project config overrides)
2. `.ai/review.yml` — project-level config
3. `.ai/review.yaml` — project-level config (fallback)

When both global and project configs exist, they are merged. **Merge rules:**
- Scalar values (`language`, `test_command`, `auto_update`, etc.): project wins
- List values (`priorities`, `always_check`, `ignore.paths`, `custom_rules`, `extra_bash`, `extra_skills`): additive — global items first, then project items, deduplicated
- `tools.mcps`: additive; if same `server` appears in both, project entry takes precedence
- `tools.static_analysis`: additive, deduplicated

If neither global nor project config is found, the review proceeds with stack auto-detection and default lenses.

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
    - nestjs                    # laravel | phalcon | express | fastapi | flask | ...

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

  # ── Tool Integration ──────────────────────────────────────────────────────
  tools:
    test_command: "npm test"    # Command to run tests. null to disable.
    static_analysis:            # Tools to run before or alongside the review
      - eslint
      - semgrep
    # PHP:    phpstan | psalm
    # Rust:   cargo clippy
    # Go:     go vet | staticcheck
    # Python: mypy | ruff

    # ── Extra Bash Commands (optional) ───────────────────────────────────────
    # Additional bash command patterns to allow during the review.
    # Useful when installed globally and the project uses non-default tools.
    extra_bash:
      - "docker:*"
      - "kubectl:*"

    # ── MCP Post-Review Actions (optional) ───────────────────────────────────
    # Configure which MCP servers to use for post-review actions.
    # server:    MCP server name as registered in Claude Code (/mcp list)
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

    # ── Extra Skills (optional) ───────────────────────────────────────────────
    # Explicit paths to SKILL.md files to incorporate as lens sources.
    # These are read (not invoked) to enrich specialist passes.
    extra_skills:
      - ~/.claude/skills/security-deep-scan/SKILL.md

  # ── Custom Rules ──────────────────────────────────────────────────────────
  custom_rules:
    - "Authorization checks must come before any data mutation."
    - "Never call external HTTP services inside a database transaction."
    - "All public API endpoints must have at least one integration test."
```

## Global Config (`~/.ai/review.yml`)

Create `~/.ai/review.yml` to set defaults that apply across all projects. This is especially useful when the skill is installed globally and individual projects don't have a local config.

Common uses:
- Configure MCP servers once instead of per-project
- Specify always-available tools (`extra_bash`)
- Point to personal skill libraries (`extra_skills`)

```yaml
review:
  tools:
    extra_bash:
      - "docker:*"
      - "kubectl:*"
    mcps:
      - server: github
        use_for: [create_issue, add_pr_comment]
      - server: jira
        use_for: [create_ticket]
    extra_skills:
      - ~/.claude/skills/security-deep-scan/SKILL.md
```

Project `.ai/review.yml` always takes precedence over global values. See [Config Discovery Order](#config-discovery-order) for merge rules.

## Custom Rules Best Practices

Write rules as concrete, verifiable invariants — not vague principles:

```yaml
# Good — specific and actionable
custom_rules:
  - "Eloquent scopes must not contain ORDER BY; ordering belongs at the query call site."
  - "Service classes must not import from the Http namespace."
  - "Every migration must have a matching down() method."

# Avoid — too vague to enforce
custom_rules:
  - "Write clean code."
  - "Follow best practices."
```

## Per-Stack Presets

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
    test_command: "./vendor/bin/pest"
    static_analysis: [phpstan, psalm]
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
    test_command: "npm test"
    static_analysis: [eslint, semgrep]
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
    test_command: "cargo test"
    static_analysis: [cargo clippy]
```

### Go

```yaml
review:
  language: go
  priorities: [correctness, security, performance]
  always_check: [error_handling, goroutine_leaks, context_propagation]
  memory:
    file: .ai/review-memory.md
    auto_update: false
  tools:
    test_command: "go test ./..."
    static_analysis: [go vet, staticcheck]
```

### Docker / CI Only

```yaml
review:
  language: dockerfile
  priorities: [security, operations]
  always_check: [image_pinning, secrets, permissions, deploy_ordering, health_checks]
```
