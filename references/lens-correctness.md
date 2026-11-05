# Correctness & Concurrency Lens

Apply to every diff that introduces state transitions, concurrency, async flows, error handling, calculations, or external contract changes.

## Severity Guide

| Severity | Impact | Examples |
|---|---|---|
| **P0** (Blocker) | Silent data corruption, deadlocks, financial calculation errors, unhandled panic/crash | Race condition in balance debit; integer overflow in financial logic; unhandled promise rejection crashing Node.js runtime; goroutine leak exhausting memory |
| **P1** (Likely bug) | Broken feature contract, unhandled edge case, state inconsistency | Off-by-one in pagination boundary; timezone naive datetime comparison causing wrong schedule; unhandled error branch swallowing failures silently |
| **P2** (Maintainability) | Brittle logic, implicit assumptions, weak validation | Type narrowing missing exhaustive switch check; redundant retry without backoff; implicit default mask missing data |
| **P3** (Minor) | Cosmetic consistency, edge case with minimal real-world impact | Non-canonical error message wording; minor naming inconsistency in internal interface |

---

## Concurrency & State

- **Race Conditions & Shared State**:
  - Check for read-modify-write patterns on shared memory without synchronization (e.g. mutex, atomic operations, channels).
  - Time-of-Check to Time-of-Use (TOCTOU): verifying a condition (e.g., file exists, balance > 0) in one step and acting on it in another without locking allows concurrent modification.
- **Deadlock Risks**:
  - Mutexes or locks acquired in inconsistent orders across different code paths.
  - Holding locks across blocking I/O or network requests.
- **Goroutines / Async Task Leaks**:
  - Go: Ensure every goroutine started has a defined termination path (context cancellation, closed channel, or timeout).
  - Node.js / Python asyncio: Ensure all background promises/tasks are awaited, tracked in a set, or have error handlers attached (`.catch()`).
- **Idempotency**:
  - Ensure operations designed for retries (e.g., payment webhooks, queue consumers) use idempotency keys or verify existing state before applying side effects.

---

## Edge Cases, Nullability & Types

- **Null and Undefined Safety**:
  - Safe navigation (`?.`) without default values where null is illegal downstream.
  - In TypeScript: avoid non-null assertion operator (`!`) unless guaranteed by preceding guards.
  - In Go: check for nil pointers before dereferencing struct fields or calling methods.
  - In Python: check for `None` before subscripting or calling methods.
- **Boundary & Off-By-One Errors**:
  - Check `<= vs <` and `>= vs >` on array indexing, pagination offset/limit, ranges, and slice slicing.
  - Zero-length collections: ensure functions handle empty lists, maps, or strings without index out of bounds or division by zero.
- **Time, Date & Timezones**:
  - Ensure all database storage and internal processing use UTC.
  - Avoid comparing naive datetime objects with timezone-aware datetime objects (common in Python).
  - Leap years, month boundaries (e.g. adding 1 month to Jan 31), daylight saving transitions.
- **Numbers & Math**:
  - Monetary values must use decimal types (`BigDecimal`, `Decimal`, or integer cents) — never floating point (`float`, `double`).
  - Integer overflow when casting between types (e.g. `int64` to `int32`).

---

## Error Handling & Contracts

- **Never Swallow Errors Silently**:
  - Empty `catch {}` blocks or `except Exception: pass` without logging or re-raising.
  - In Go: never ignore returned errors (`_ = doSomething()`).
- **Partial Failure & Rollback**:
  - If step 3 of a 5-step non-transactional process fails, does the system leave orphan records or inconsistent state?
- **Backward Compatibility**:
  - Changing API response shapes, removing fields, or adding required request fields without versioning breaks clients.
  - Renaming public exports, function signatures, or protobuf/gRPC message tags.

