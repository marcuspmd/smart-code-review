# Data, SQL, and Migrations Lens

Apply to every diff that touches database migrations, ORM entities, queries, repositories, transactions, connection pooling, or schema definitions.

## Severity Guide

| Severity | Impact | Examples |
|---|---|---|
| **P0** (Blocker) | Data loss, table locks in production, deadlock under load | `ALTER TABLE` adding non-null column without default on large table; exclusive lock without timeout; destructive migration without backup step; long transaction wrapping external HTTP call |
| **P1** (Likely bug) | Performance degradation, data corruption, migration failure | Missing index on foreign key or heavily queried column; `CREATE INDEX` without `CONCURRENTLY` in Postgres; transaction isolation mismatch; unhandled unique constraint collision |
| **P2** (Maintainability) | Incomplete rollback, migration hygiene, schema drift | Missing or broken `down()` migration method; non-idempotent migration; raw SQL where ORM abstraction is established; mixed schema change and data backfill in single step |
| **P3** (Minor) | Style, minor optimization, documentation | Index name does not match project convention; redundant query alias; unindexed low-cardinality lookup in small table |

---

## Migration Safety & Zero-Downtime

- **Additive Changes First (Expand/Contract pattern)**:
  - Phase 1 (Expand): Add new columns or tables as nullable or with defaults. Deploy app that writes to both old and new.
  - Phase 2 (Backfill): Run async backfill data scripts outside the deployment lock window.
  - Phase 3 (Contract): Switch reads to new column, drop old column in a subsequent release.
- **Locking & Blocking Operations**:
  - Postgres: `CREATE INDEX` must use `CONCURRENTLY` on populated production tables to prevent read/write locks.
  - Postgres: `ALTER TABLE ADD COLUMN NOT NULL` without a default value requires a full table rewrite on older versions and locks the table.
  - Postgres/MySQL: Changing column types (e.g. `VARCHAR(50)` to `TEXT` or `INT` to `BIGINT`) can hold exclusive locks for minutes/hours on large tables.
  - MySQL: Adding or dropping foreign keys locks the table depending on engine and `ALGORITHM=INPLACE` settings.
- **Lock Timeouts**:
  - Migrations on busy tables should set a strict `lock_timeout` (e.g., `SET lock_timeout = '2s';`) so they abort and retry rather than queueing up and causing cascading connection pool exhaustion.
- **Idempotency & Rollback**:
  - Migrations must be safely repeatable (`IF NOT EXISTS`, `IF EXISTS`).
  - Every migration file should provide a tested, valid rollback path (`down()` method or reverse migration script).

---

## Transaction Scope & Concurrency

- **No I/O or External Calls inside Transactions**:
  - Never place HTTP requests, queue publications (unless transactional outbox pattern), email sends, or long file I/O inside database transaction boundaries (`BEGIN ... COMMIT`).
  - If the external call hangs or times out, database connection holds locks open, starving the connection pool.
- **Lock Ordering & Deadlocks**:
  - When acquiring row-level locks on multiple rows (e.g., `SELECT ... FOR UPDATE`), ensure rows are locked in a deterministic, sorted order (e.g., sorted by ID) to eliminate deadlocks.
- **Transaction Granularity**:
  - Keep transactions as short and scoped as possible.
  - Do not wrap read-only operations or preparation logic inside the transaction block.

---

## Queries, Indexes & Performance

- **N+1 Query Detection**:
  - Check loops iterating over collections that execute queries inside each iteration.
  - Ensure eager loading is used (`with()` in Laravel/Eloquent, `select_related()` / `prefetch_related()` in Django, `joinedload` in SQLAlchemy, `relations` in TypeORM).
- **Index Alignment**:
  - New filter conditions (`WHERE status = ? AND tenant_id = ?`) must match existing composite indexes in leading column order.
  - Foreign keys must have indexes on the child table to prevent full table scans on `JOIN` and `ON DELETE` cascades.
- **Unbounded Queries**:
  - Ensure all collection endpoints or batch operations have mandatory `LIMIT` or pagination.
  - Avoid `SELECT *` on wide tables with `TEXT` or `BLOB` columns; select only needed fields.
- **Uniqueness & Race Conditions**:
  - Application-level uniqueness checks (`if (!exists) create`) are prone to race conditions without a database-level `UNIQUE` constraint or conditional `INSERT ... ON CONFLICT` / `ON DUPLICATE KEY UPDATE`.

---

## Stack-Specific Checks

### PostgreSQL
- `CREATE INDEX CONCURRENTLY` cannot run inside an explicit transaction block; must run with auto-commit enabled.
- Verify `pg_trgm` or `gin` indexes for pattern-matching queries (`ILIKE '%term%'`).
- Use `JSONB` instead of `JSON` for indexed queryable document columns.

### MySQL / MariaDB
- Ensure charset is `utf8mb4` with collation `utf8mb4_unicode_ci` or `utf8mb4_0900_ai_ci`.
- Online DDL: check whether `ALGORITHM=INPLACE, LOCK=NONE` is supported for the altered column.

### Laravel / Eloquent
- Check for `$fillable` vs `$guarded`.
- Avoid calling `$model->touch()` in batch loops.
- Use `lazyById()` or `chunkById()` instead of `chunk()` when modifying records during iteration to avoid skipping rows.

### Django / SQLAlchemy (Python)
- Django: Avoid `count()` in template or condition if the queryset is evaluated later (use `len()` or `exists()`).
- SQLAlchemy: Explicitly manage session commit/rollback; avoid leaving uncommitted sessions in thread-local pools.

