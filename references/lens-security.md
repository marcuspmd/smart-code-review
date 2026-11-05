# Security Lens

Apply to every diff that touches: auth, permissions, input/output, HTTP endpoints, file operations, crypto, sessions, or external integrations. When in doubt, run it.

## Severity Guide

| Severity | Impact | Examples |
|---|---|---|
| **P0** (Blocker) | Remote code execution (RCE), unauthenticated data breach, privilege escalation | SQL injection; arbitrary file upload; hardcoded production private key; missing authentication guard on admin route |
| **P1** (Likely bug) | High-risk vulnerability under specific conditions, IDOR, SSRF | Object-level authorization bypass (IDOR); SSRF reaching private IP ranges; reflected XSS; mass assignment mutating permissions |
| **P2** (Maintainability) | Defense-in-depth weakness, weak defaults, missing rate limit | Missing rate limit on password reset; weak password policy; wildcard CORS on semi-sensitive endpoint; verbose error traces in responses |
| **P3** (Minor) | Minor hygiene, informational security improvement | Missing security headers (X-Frame-Options); token entropy slightly lower than recommended; outdated dependency without known exploit |

---

## Authorization

- Every endpoint that reads/writes data verifies the caller owns or has permission to **that specific resource** (object-level check, not just role-level).
- Permission checks happen **before** data mutation, never after.
- Admin-only operations: verify the guard is enforced at the route/middleware level, not just documented.
- Horizontal privilege escalation: can user A access user B's resource by changing an ID in the request?
- Mass assignment: ORM models explicitly declare `fillable`/`guarded` — no `$fillable = ['*']` or spreading `req.body` directly into a DB call.

## Authentication

- Token/session validation is not accidentally bypassed on new routes (middleware ordering matters).
- JWT: algorithm is hardcoded server-side — `none` algorithm is rejected.
- JWT: `exp`, `iss`, and `aud` are validated.
- Password reset and email verification tokens are single-use and short-lived.
- Login failures do not leak whether an email/username exists (timing attack + enumeration).
- MFA bypass: new flows don't skip MFA for specific code paths.

## Injection

- **SQL**: parameterized queries / ORM throughout — zero raw string interpolation with user input. Check `ORDER BY` and `LIMIT` clauses too (often missed).
- **NoSQL**: user input is not used as query operators (`$where`, `$expr`, `$regex`).
- **Command**: user input never reaches `exec`, `system`, `popen`, `child_process.exec`, `shell_exec`.
- **Template**: user-controlled strings are not rendered by template engines (Twig, Blade, Jinja, Handlebars).
- **LDAP**: user input is escaped before LDAP queries.

## XSS

- User-controlled content is escaped before rendering in HTML.
- `dangerouslySetInnerHTML`, `innerHTML`, `v-html`, `[innerHtml]` only used with sanitized/trusted content.
- CSP headers are not weakened by the diff.
- JSON responses embedded in HTML use `Content-Type: application/json`.

## SSRF

- URLs built from user input are validated against an explicit allowlist of domains/schemes.
- Internal network addresses (`169.254.x.x`, `10.x.x.x`, `172.16.x.x`, `127.x.x.x`, `localhost`) are blocked.
- HTTP redirects from user-controlled URLs are not followed blindly.

## Path Traversal

- File paths derived from user input are canonicalized (resolve symlinks) and confirmed to stay within the allowed root directory.
- `../` and URL-encoded equivalents (`%2F`, `%2e%2e`) are stripped or rejected before file operations.

## Secrets and Credentials

- No secrets, API keys, tokens, or passwords hardcoded in source or test fixtures.
- `.env.example` is updated when new env vars are introduced.
- Secrets are not written to logs, error messages, or API responses.
- Credentials are not committed inside config files, migrations, or seed files.

## Cryptography

- Passwords hashed with bcrypt, argon2, or scrypt — never MD5, SHA1, SHA256, or unsalted hashes.
- Random values for security purposes use CSPRNG (`crypto.randomBytes`, `random_bytes`, `secrets` in Python, `crypto/rand` in Go) — not `Math.random()`, `rand()`, or `math/rand`.
- Encryption uses authenticated modes (AES-GCM, ChaCha20-Poly1305) — not ECB or unauthenticated CBC.
- TLS: new HTTP clients do not disable certificate verification (`verify: false`, `rejectUnauthorized: false`, `InsecureSkipVerify: true`).

## Rate Limiting and DoS

- Auth endpoints (login, password reset, OTP, magic link) are rate-limited.
- File upload endpoints limit size and validate MIME type server-side (not only client-side).
- Loops, queries, and batch operations over user-controlled counts have a bounded upper limit.
- Regex patterns applied to user input are not vulnerable to ReDoS (avoid catastrophic backtracking).

## CORS and Headers

- `Access-Control-Allow-Origin` is not set to `*` on authenticated or sensitive endpoints.
- `Access-Control-Allow-Credentials: true` is not combined with a wildcard origin.
- Security headers (CSP, HSTS, X-Content-Type-Options, X-Frame-Options) are not removed by the diff.

## Sensitive Data Exposure

- API responses do not leak internal fields: passwords, raw tokens, internal IDs, stack traces, DB queries.
- Error responses in production return generic messages — stack traces are suppressed.
- PII is not logged unless explicitly required and compliant with the project's data retention policy.

---

## Stack-Specific Checks

### Python (Django, FastAPI, Flask)
- `pickle.loads()` on untrusted data → arbitrary code execution (RCE).
- `subprocess.run(..., shell=True)` with formatted strings → command injection.
- SQLAlchemy `text("SELECT ... " + user_var)` or Django `extra(where=[...])` / `raw()` → SQL injection.
- `yaml.load(stream)` without `Loader=yaml.SafeLoader` → arbitrary Python object instantiation.
- `eval()`, `exec()`, or `compile()` with user-controlled input → arbitrary code execution.
- Jinja2 templates initialized with `autoescape=False` → cross-site scripting (XSS).
- Pydantic models accepting arbitrary kwargs or unbounded string lengths without validation constraints.

### Go
- `fmt.Sprintf` in SQL queries passed to `db.Query` or `db.Exec` → SQL injection.
- `exec.Command("sh", "-c", userCmd)` → command injection; use explicit arg slices without shell.
- SSRF: using `http.Get(userURL)` without verifying the resolved IP is not a private/loopback/link-local address.
- `archive/zip` or `archive/tar` extraction without checking for `..` (Zip Slip path traversal).
- Concurrency data races on shared maps or slices without read-write mutex locks (`sync.RWMutex`).
- `tls.Config{InsecureSkipVerify: true}` committed in non-test code.

### Rust
- Unsound `unsafe` blocks: dereferencing raw pointers without bounds/lifetime guarantees.
- `std::mem::transmute` across types of mismatched size or alignment.
- Executing shell commands with `std::process::Command::new("sh")` and unescaped input.
- Deserializing untrusted binaries or untrusted serde types without depth/size limits (DoS).

### PHP / Laravel
- `DB::statement()` or `DB::select()` with string interpolation → SQL injection.
- `Request::all()` or `$request->input()` passed to `create()`/`fill()` without explicit validation → mass assignment.
- Missing `authorize()` in FormRequest → verify manual policy check exists in controller/action.
- `Storage::get($path)` where `$path` derives from user input → path traversal.
- `unserialize()` on user-controlled input → arbitrary object injection.

### TypeScript / Node
- `eval()`, `new Function(string)`, `vm.runInNewContext()` with user input → code injection.
- `child_process.exec()` with template literals → command injection; prefer `execFile()` with arg arrays.
- `res.setHeader('Access-Control-Allow-Origin', req.headers.origin)` unconditionally → CORS bypass.
- MongoDB: object spread of `req.body` directly into query → NoSQL injection.

### SQL (any stack)
- String interpolation in `WHERE`, `ORDER BY`, `LIMIT`, `GROUP BY` → SQL injection.
- `ORDER BY` on user-controlled column names without an explicit allowlist.
- Dynamic table names constructed from user input.
