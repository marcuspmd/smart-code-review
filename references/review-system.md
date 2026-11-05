# Review System Reference

Use this reference when setting up or refining the code review workflow, creating review config, tuning memory, or selecting specialist checks.

## Suggested Project Files

```text
.ai/review.yml          # Core review configuration (lenses, tools, priorities, ignore rules)
.ai/review-memory.md    # Persistent review memory (recurring issues, accepted patterns, false positives)
.ai/review-rules.md     # Optional freeform repository rules and guidelines in Markdown
docs/architecture.md    # Durable architectural design decisions
docs/conventions.md     # Code style and framework guidelines
docs/adr/               # Architecture Decision Records
```

Keep durable project decisions in docs or ADRs. Keep review-specific recurring lessons in memory. When `.ai/review-rules.md` exists, the agent loads and respects its guidelines during review passes.

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

## Specialist Lenses

Detailed checklists and P0–P3 severity rubrics are available in dedicated lens documents:

- **Security Lens**: [`references/lens-security.md`](lens-security.md) — Authorization, injection, XSS, SSRF, path traversal, secrets, crypto, CORS.
- **Data & Migrations Lens**: [`references/lens-data.md`](lens-data.md) — Zero-downtime migrations, lock timeouts, transaction scopes, N+1, composite indexes.
- **Correctness & Concurrency Lens**: [`references/lens-correctness.md`](lens-correctness.md) — Race conditions, deadlocks, null safety, boundaries, error swallowing.
- **Performance Lens**: [`references/lens-performance.md`](lens-performance.md) — Unbounded queries, memory leaks, event loop blocking, cache stampede.
- **Architecture Lens**: [`references/lens-architecture.md`](lens-architecture.md) — Layering, DDD boundaries, dependency inversion, fat controllers.
- **Accessibility (A11y) Lens**: [`references/lens-a11y.md`](lens-a11y.md) — WCAG 2.1 AA, keyboard nav, ARIA, focus, contrast.

### Summary of Core Passes

- **Security**: Check authorization before state changes, object-level permission checks, input validation, SQL/NoSQL injection, XSS, CSRF, SSRF, path traversal, unsafe file upload, secrets in code, weak crypto, and over-broad logs.
- **Correctness**: Check changed contracts, nullability, race conditions, idempotency, retry behavior, boundary values, time zone handling, partial failure paths, exception behavior, and backward compatibility.
- **Data, SQL, and Transactions**: Check missing indexes, incorrect uniqueness, unsafe nullable changes, destructive migrations, deploy ordering, N+1 queries, transaction scope, deadlock risk, external calls inside transactions, and absent rollback paths.
- **Architecture**: Check dependency direction, domain/application/infrastructure boundaries, fat controllers, entities depending on repositories, framework leakage into domain models, duplicated business rules, and unclear ownership.
- **Performance**: Check unbounded loops, repeated queries, inefficient joins, high-cardinality cache keys, cache invalidation, memory growth, unnecessary serialization, blocking I/O, and concurrency bottlenecks.
- **Tests**: Check whether changed behavior has a focused test, whether edge cases are covered, whether fixtures hide important state, and whether integration tests are needed for persistence, permissions, queues, or transactions.
- **Operations**: Check container image pinning, build reproducibility, secrets exposure in CI/CD pipelines, environment variable parity, health check endpoints, and deploy sequencing.

## Stack-Specific Prompts

### Python (FastAPI, Django, Flask, SQLAlchemy, Pydantic)

- Inspect async endpoints for blocking synchronous calls (e.g. `requests.get` or blocking DB drivers in `async def`).
- Check ORM queries for N+1 issues: ensure `select_related()` / `prefetch_related()` in Django or `joinedload()` in SQLAlchemy.
- Watch for mutable default arguments in functions (`def foo(items=[])`).
- Inspect Pydantic models for validation gaps: beware of `model_validate()` on unvalidated raw dicts without schema stripping.
- Check datetime objects: avoid mixing naive and timezone-aware datetimes.

### Go

- Inspect goroutine lifecycles: ensure every spawned goroutine has a termination guarantee via `context.Context` or quit channels.
- Inspect error handling: verify `if err != nil` is never swallowed or ignored.
- Check mutex locking patterns: verify `mu.Lock()` is immediately followed by `defer mu.Unlock()`, and lock is not held across network I/O.
- Check loop variable pointer aliasing (in Go < 1.22) and map/slice concurrency races (`go test -race`).
- Ensure `http.Response.Body` is closed with `defer resp.Body.Close()`.

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
