# Output Format

Every review must follow this structure exactly. Consistency makes reviews scannable and easy to act on.

## Full Template

```
## Code Review — [branch name / commit sha / description]

**Stack**: [detected language + framework]
**Scope**: [N files changed, +X / -Y lines]
**Tools**: [tools run, or "none"]
**Memory**: [loaded (N entries) | not found]

---

### Summary

[2–4 sentences. What changed, what the overall quality signal is, and the one or two most important things to address. Do not list findings here — just the narrative.]

---

### Findings

[Ordered P0 first, then P1, P2, P3. Omit severity levels that have no findings.]

#### P0 — [Short imperative title]

**File**: `path/to/file.ts:142`
**Risk**: [One sentence — what breaks, for whom, under what condition.]
**Fix**: [Concrete change or command to validate. Not "consider refactoring" — a specific action.]

---

#### P1 — [Short imperative title]

**File**: `path/to/file.ts:87`
**Risk**: [...]
**Fix**: [...]

---

#### P2 — [Short imperative title]

**File**: `path/to/file.ts:210`
**Risk**: [...]
**Fix**: [...]

---

#### P3 — [Short imperative title]

**File**: `path/to/file.ts:34`
**Risk**: [...]
**Fix**: [...]

---

### Open Questions

[Include only when a question directly affects a finding's severity or validity. Skip this section if there are none.]

- [Question that needs answer before the finding can be resolved]

---

### Recommendation

**[APPROVE | REQUEST_CHANGES | COMMENT]** — [One sentence reason.]

---

### Memory Suggestions

[Include only when a finding reveals a recurring pattern worth persisting. Skip if nothing is worth saving.]

> Run after review to persist:
> ```bash
> bash {baseDir}/scripts/write-memory.sh --section "[Section]" --entry "[entry text]"
> ```
```

---

## Severity Reference

| Level | Meaning | Action required |
|---|---|---|
| **P0** | Data loss, security breach, production outage, hard merge blocker | Block merge |
| **P1** | Likely bug, serious security/performance regression, broken core workflow | Block merge |
| **P2** | Meaningful risk to maintainability, architecture, tests, or edge cases | Fix before or shortly after merge |
| **P3** | Low-risk improvement, only worth noting on an otherwise clean review | Optional |

**Rules:**
- A finding must be grounded in a specific file+line when available. "Generally" or "throughout the codebase" is not a finding.
- Severity comes from **impact in this codebase**, not from tool severity output.
- One real issue = one finding, even if multiple lenses or tools caught it.

---

## Recommendation Values

| Value | When to use |
|---|---|
| **APPROVE** | No P0/P1 findings; P2/P3 are optional to address |
| **REQUEST_CHANGES** | One or more P0 or P1 findings that must be resolved before merge |
| **COMMENT** | Observations only — no blocking findings, but questions or context worth sharing |

---

## Clean Review (No Findings)

When no findings are found, do not fabricate P3s to appear thorough. Use:

```
## Code Review — [description]

**Stack**: [...]
**Scope**: [...]
**Tools**: [...]
**Memory**: [...]

---

### Summary

[What changed and why it looks correct. Mention which lenses were applied and any tool output.]

---

### Findings

No findings.

---

### Recommendation

**APPROVE** — [One sentence confirming what was checked and that it looks good.]
```

---

## Examples

### Example 1: Security + Test Finding

```
## Code Review — feature/jwt-refresh

**Stack**: TypeScript / NestJS
**Scope**: 4 files changed, +187 / -23
**Tools**: eslint (0 errors), npm test (47 passed)
**Memory**: loaded (3 entries)

---

### Summary

Adds JWT refresh token support with a new `/auth/refresh` endpoint and token rotation.
The rotation logic is correct, but the refresh endpoint is missing rate limiting and the
token is exposed in an error log. Both issues must be resolved before merge.

---

### Findings

#### P1 — Refresh token exposed in error log

**File**: `src/auth/auth.service.ts:94`
**Risk**: If the catch block runs, the raw refresh token is logged via `this.logger.error(err, { token })`. Any log aggregation system (Datadog, CloudWatch) will store the token in plain text, allowing anyone with log access to hijack sessions.
**Fix**: Remove `token` from the log context: `this.logger.error('Refresh failed', { userId })`.

---

#### P1 — No rate limiting on /auth/refresh

**File**: `src/auth/auth.controller.ts:31`
**Risk**: The endpoint accepts unlimited requests. An attacker with a stolen refresh token can probe token rotation indefinitely or use the endpoint for brute-force enumeration.
**Fix**: Apply `@Throttle(10, 60)` (10 requests/minute) consistent with the login endpoint.

---

#### P2 — Refresh token rotation not tested for concurrent requests

**File**: `src/auth/auth.service.spec.ts`
**Risk**: The test suite covers happy path and expired token scenarios but not concurrent refresh calls with the same token. Concurrent calls may both succeed and issue different new tokens, leaving one valid — a known race condition in token rotation.
**Fix**: Add a test that fires two concurrent refresh requests with the same token and asserts only one succeeds.

---

### Recommendation

**REQUEST_CHANGES** — Two P1 findings (token in logs, no rate limiting) must be resolved before merge.

---

### Memory Suggestions

> Run after review to persist:
> ```bash
> bash {baseDir}/scripts/write-memory.sh --section "Recurring Issues" --entry "Tokens and credentials are sometimes included in logger.error() context objects — check all catch blocks"
> ```
```

---

### Example 2: Clean Review

```
## Code Review — fix/user-pagination-offset

**Stack**: TypeScript / NestJS / TypeORM
**Scope**: 2 files changed, +18 / -6
**Tools**: eslint (0 errors), npm test (52 passed)
**Memory**: loaded (3 entries)

---

### Summary

Fixes an off-by-one error in the user list pagination offset calculation. The fix is
minimal and correct — the formula change is consistent with how the frontend sends
page numbers (1-indexed). Test coverage was updated to include page=1 and page=2 cases.

---

### Findings

No findings.

---

### Recommendation

**APPROVE** — Pagination fix is correct, tests cover the boundary cases, no security or performance concerns.
```
