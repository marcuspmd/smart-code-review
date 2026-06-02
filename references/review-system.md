# Review System Reference

Use this reference when setting up or refining the code review workflow, creating review config, tuning memory, or selecting specialist checks.

## Suggested Project Files

```text
.ai/review.yml
.ai/review-memory.md
.ai/review-rules.md
docs/architecture.md
docs/conventions.md
docs/adr/
```

Keep durable project decisions in docs or ADRs. Keep review-specific recurring lessons in memory.

## Review Config Example

```yaml
review:
  language: php
  frameworks:
    - laravel

  priorities:
    - security
    - correctness
    - performance
    - architecture
    - tests

  always_check:
    - sql_injection
    - authorization
    - n_plus_one
    - transaction_scope
    - ddd_layers
    - affected_tests

  ignore:
    paths:
      - vendor/**
      - node_modules/**
      - dist/**
      - coverage/**
    categories:
      - generated_code

  memory:
    file: .ai/review-memory.md
    auto_update: false

  tools:
    test_command: null
    static_analysis:
      - phpstan
      - psalm
      - semgrep

  custom_rules:
    - "Never use repositories inside entities."
    - "Actions must validate permissions before mutating state."
    - "Avoid nested foreach loops in reports unless data volume is bounded."
```

## Memory File Example

```md
# Review Memory

## Architecture

- The project uses DDD-style boundaries; keep domain logic out of controllers.
- Prefer constructor injection over service locator patterns.

## Recurring Issues

- Reports are prone to N+1 queries.
- Transaction boundaries are often too wide around external calls.

## Accepted Patterns

- Migrations may be split into schema and backfill steps for safer deploys.

## False Positives

- Some generated API clients intentionally violate local naming conventions.
```

## Specialist Lens Details

### Security

Check authorization before state changes, object-level permission checks, input validation, SQL/NoSQL injection, XSS, CSRF, SSRF, path traversal, unsafe file upload, secrets in code, weak crypto, and over-broad logs.

### Correctness

Check changed contracts, nullability, race conditions, idempotency, retry behavior, boundary values, time zone handling, partial failure paths, exception behavior, and backward compatibility.

### Data, SQL, and Transactions

Check missing indexes, incorrect uniqueness, unsafe nullable changes, destructive migrations, deploy ordering, N+1 queries, transaction scope, deadlock risk, external calls inside transactions, and absent rollback paths.

### Architecture

Check dependency direction, domain/application/infrastructure boundaries, fat controllers, entities depending on repositories, framework leakage into domain models, duplicated business rules, and unclear ownership.

### Performance

Check unbounded loops, repeated queries, inefficient joins, high-cardinality cache keys, cache invalidation, memory growth, unnecessary serialization, blocking I/O, and concurrency bottlenecks.

### Tests

Check whether changed behavior has a focused test, whether edge cases are covered, whether fixtures hide important state, and whether integration tests are needed for persistence, permissions, queues, or transactions.

## Stack-Specific Prompts

### PHP, Laravel, and Phalcon

- Inspect controllers/actions for missing permission checks and validation.
- Inspect Eloquent/ORM usage for N+1 queries, eager loading, mass assignment, and transaction scope.
- Use PHPUnit or Pest conventions when suggesting tests.
- Use PHPStan or Psalm findings as inputs, not as unquestioned conclusions.

### TypeScript, Node, Bun, and Zod

- Inspect async error handling, promise concurrency, type narrowing, runtime validation, and API boundaries.
- Prefer current project conventions for package manager and runtime.
- For Zod v4-style code, prefer `z.uuid()` over deprecated `z.string().uuid()` when validating UUIDs.

### Rust

- Inspect ownership-sensitive changes, error propagation, async boundaries, lock scope, panic paths, trait contracts, and unsafe blocks.

### Docker and CI

- Inspect image pinning, build context, secrets, permissions, health checks, exposed ports, cache behavior, reproducibility, and deploy-time migration ordering.

## Review Consolidation Rules

- One real issue should produce one finding, even if multiple lenses discover it.
- Prefer fewer, stronger findings over a long list of speculative notes.
- Do not invent a severity from tool output alone; severity comes from impact in this codebase.
- If line numbers are unavailable, reference the smallest reliable file/function/symbol scope.
- Include "no findings" only when the review actually checked the relevant diff and context.

