# Performance & Scalability Lens

Apply to diffs modifying high-throughput paths, batch jobs, search endpoints, data transformations, serialization, loops, or caching layers.

## Severity Guide

| Severity | Impact | Examples |
|---|---|---|
| **P0** (Blocker) | Out of memory (OOM) crash, thread pool exhaustion, cascading failure | Loading millions of records into memory without streaming; infinite recursion or unbounded retry storm; holding DB connections during external API rate limit pauses |
| **P1** (Likely bug) | Latency spike, severe throughput drop, cache stampede | N+1 database queries in user-facing list endpoint; regex catastrophic backtracking (ReDoS); missing TTL on rapidly growing Redis keys |
| **P2** (Maintainability) | Inefficient resource utilization, sub-optimal query plan | Unnecessary JSON deep cloning or serialization in hot path; unindexed query on moderately sized table; redundant duplicate network fetch |
| **P3** (Minor) | Micro-optimization, minor allocation improvements | String concatenation in small loop where builder is cleaner; suboptimal collection initialization size |

---

## Data Fetching & Queries

- **N+1 Queries**:
  - Never execute SQL/database queries inside loops over list items.
  - Inspect ORM relations: ensure eager loading (`with()`, `select_related()`, `prefetch_related()`, `joinedload`) is used on accessed relationships.
- **Unbounded Result Sets**:
  - All queries fetching collections must include `LIMIT` and pagination or cursor-based scrolling.
  - Large exports/reports must stream results or use chunked processing (`lazy()`, `cursor()`, `chunkById()`).
- **Heavy Projections**:
  - Avoid `SELECT *` when only 2 or 3 columns are needed, especially on tables with large text, JSON, or binary fields.

---

## Memory & Allocations

- **Memory Leaks & Accumulators**:
  - Check global caches, module-level variables, or event listener arrays that add items without eviction policies.
  - In Node.js: stream file uploads and downloads (`pipe()`, `stream/promises`) rather than buffering into `Buffer.concat()`.
  - In Go: avoid retaining large slices in memory when only a small sub-slice is needed (slices keep the entire underlying array allocated).
- **Hot-Loop Allocations**:
  - In high-throughput paths, avoid allocating large objects, regex compilations, or reflection inside tight loops.

---

## Caching Strategy

- **Cache Invalidation & Consistency**:
  - When mutating an entity, are all related cache keys invalidated or updated?
  - Does the cache key include all parameters determining the output (e.g., user permissions, tenant ID, currency)?
- **Cache Stampede (Thundering Herd)**:
  - For expensive calculations or heavy queries, protect cache misses with mutex locks, probabilistic early expiration (XFetch), or background refresh.
- **TTL & Expiration**:
  - Every dynamic key placed in Redis, Memcached, or in-memory stores must have an explicit TTL to avoid unbounded memory growth.

---

## Concurrency & I/O

- **Blocking the Event Loop**:
  - In Node.js or Python asyncio: never execute synchronous CPU-heavy algorithms, synchronous filesystem calls (`fs.readFileSync`), or crypto operations on the main event loop thread.
- **Parallel vs Sequential I/O**:
  - Multiple independent network calls should be executed concurrently (`Promise.all()`, `asyncio.gather()`, `errgroup.Group`) rather than sequentially awaited.
- **Connection Pooling**:
  - Ensure database, Redis, and HTTP client connection pools are reused as singletons rather than instantiating new client pools per request.

