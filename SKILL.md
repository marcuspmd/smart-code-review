---
name: code-review-agent
description: Context-aware code review with memory, configurable rules, specialist lenses, and automated tool integration. Runs tests, linters, and static analyzers alongside the review. Use when reviewing PRs, diffs, commits, or local changes before merge. Use when inspecting PHP/Laravel, TypeScript/NestJS, Rust, Go, Python, Docker, SQL, or CI changes. Use when running automated checks, creating review rules, or tuning project review memory. Trigger with "review my changes", "review my open changes", "review this PR", "review against develop", "review against main", "review the last N commits", "check my diff", "run code review", "review before merge".
allowed-tools: "Read,Glob,Grep,Bash(bash:*),Bash(git:*),Bash(rg:*),Bash(npm:*),Bash(npx:*),Bash(yarn:*),Bash(pnpm:*),Bash(composer:*),Bash(pest:*),Bash(phpunit:*),Bash(cargo:*),Bash(go:*),Bash(pytest:*),Bash(phpstan:*),Bash(psalm:*),Bash(semgrep:*),Bash(eslint:*)"
version: "1.2.0"
---

# Code Review Agent

Context-aware AI code review with project configuration, persistent memory, specialist lenses, and automated tool integration.

## Overview

This skill runs a structured code review by loading project context (config, memory, architecture docs), identifying the diff surface, applying specialist lenses (correctness, security, data, performance, architecture, tests, ops), running relevant tools, and producing prioritized findings.

Responds in the user's language unless repository conventions require otherwise.

## Prerequisites

**Required**: Git repository with staged, committed, or branch-level changes.

**Optional configuration files**:
- `.ai/review.yml` or `.codex/review.yml` — review config (lenses, tools, priorities, ignore rules, custom rules)
- `.ai/review-memory.md` — persistent review memory (recurring issues, accepted patterns, false positives)

See `{baseDir}/references/config-guide.md` for the full configuration reference.

## Instructions

### Step 1: Load Project Context

1. Load config (guaranteed — prints content or reports missing):

```bash
bash {baseDir}/scripts/load-config.sh
```

2. Load memory (guaranteed — prints content or reports missing):

```bash
bash {baseDir}/scripts/read-memory.sh
```

3. Read `AGENTS.md` files if present.
4. Skim `docs/architecture.md`, `docs/conventions.md`, `README.md`, or ADRs when visible.

### Step 2: Identify the Review Surface

Run the surface detector — it resolves the correct mode, prints stats, and outputs the exact `git diff` command to use:

```bash
# Auto mode (priority: staged → unstaged → branch ahead of base → last commit)
bash {baseDir}/scripts/detect-surface.sh

# Compare current branch to a specific target branch
bash {baseDir}/scripts/detect-surface.sh --branch develop
bash {baseDir}/scripts/detect-surface.sh --branch main
bash {baseDir}/scripts/detect-surface.sh --branch staging

# PR mode — auto-detects base branch (main / master / develop)
bash {baseDir}/scripts/detect-surface.sh --pr

# Last N commits on the current branch
bash {baseDir}/scripts/detect-surface.sh --commits 3

# Staged changes only (not yet committed)
bash {baseDir}/scripts/detect-surface.sh --staged
```

After running the detector, execute the `# command:` it printed to get the actual diff. Map user intent to mode:

| User says | Mode to use |
|---|---|
| "review my changes" / "review open changes" | `--auto` (default) |
| "review against develop / main / staging" | `--branch <name>` |
| "review this PR" / "review before merging" | `--pr` |
| "review the last 3 commits" | `--commits 3` |
| "review what I staged" | `--staged` |

Do not review unstaged changes alongside staged ones unless the user explicitly asks.

### Step 3: Build Review Profile

- Detect language, framework, storage layer, test framework, runtime, and deploy surface.
- Classify changed files by role: controller, service, entity, migration, SQL, test, Docker, CI, config, docs.
- Map each file class to the most relevant lenses.

### Step 4: Run Tools When Useful

Tools increase confidence — they do not replace analysis. Run only what is cheap and relevant unless the user asked for more.

```bash
# Search for callers of a changed function
rg "functionName" --type ts

# Run affected tests (uses config or auto-detection)
bash {baseDir}/scripts/run-tests.sh

# Run linters and static analysis
bash {baseDir}/scripts/run-linters.sh
```

For per-stack tool commands and integration rules, see `{baseDir}/references/tools-guide.md`.

### Step 5: Run Specialist Passes

Run each pass relevant to the review profile. Collect findings independently per pass before merging.

**Security Pass** — run on every diff that touches endpoints, auth, input/output, file ops, crypto, or sessions:
Read `{baseDir}/references/lens-security.md` and apply every applicable checklist item to the diff.

**Correctness Pass** — broken contracts, edge cases, null handling, error paths, state transitions, backward compatibility, idempotency.

**Data Pass** — transaction scope, deadlock risk, migration safety, missing indexes, nullable/unique constraint changes, external calls inside transactions, rollback paths.

**Performance Pass** — N+1 queries, unbounded loops, missing pagination, memory pressure, caching invalidation, blocking I/O, concurrency.

**Architecture Pass** — layering violations, DDD boundary breaches, dependency direction, fat controllers, duplicated business rules, unclear ownership.

**Tests Pass** — missing tests for changed behavior, assertions that don't actually test the change, brittle fixtures, integration test gaps for persistence/permissions/queues.

**Operations Pass** — Docker image pinning, secrets in CI, env var gaps, health checks, migration/deploy sequencing, observability.

**A11y Pass** — run only if the diff touches HTML, JSX/TSX, CSS, or ARIA:
Read `{baseDir}/references/lens-a11y.md` and apply every applicable checklist item to the diff.

See `{baseDir}/references/review-system.md` for stack-specific prompts per pass.

### Step 6: Reflection / Critic Pass

Before reporting, challenge every finding collected in Step 5. For each finding, ask:

1. **In the diff?** — Is this line actually changed in this diff, or is it pre-existing code?
2. **In scope?** — Is the file excluded by `review.ignore.paths` in config?
3. **In memory?** — Does the memory file list this as a known false positive or accepted pattern?
4. **Concrete?** — Is there a specific file+line reference and a concrete fix? Speculative findings without a fix belong at P3 or get dropped.
5. **Severity accurate?** — Does the impact in this codebase match the P0–P3 scale? Do not inherit severity from tool output.

**Discard** findings that fail checks 1, 2, or 3.
**Downgrade to P3 or drop** findings that fail check 4.
**Deduplicate** findings caught by multiple passes into a single finding with the best description.

### Step 7: Format and Report

Use the template and rules in `{baseDir}/references/output-format.md` exactly.

Key rules:
- Order findings P0 → P3.
- Every finding has: title, file+line, one-sentence risk, concrete fix.
- End with a `APPROVE / REQUEST_CHANGES / COMMENT` recommendation.
- Propose memory entries for recurring patterns found — do not write them automatically unless `auto_update: true`.

## Memory Handling

### Reading memory

Always run this at the start of every review — it prints the memory file (or reports that none exists):

```bash
bash {baseDir}/scripts/read-memory.sh
```

### Writing memory

After a review, when a useful recurring lesson is found, write it with:

```bash
# Valid sections: Architecture | Recurring Issues | Accepted Patterns | False Positives | Custom Rules
bash {baseDir}/scripts/write-memory.sh --section "Recurring Issues" --entry "Reports prone to N+1 queries in analytics module"
bash {baseDir}/scripts/write-memory.sh --section "Architecture" --entry "DDD: Domain/ must not import from Infrastructure/"
bash {baseDir}/scripts/write-memory.sh --section "False Positives" --entry "PHPStan flags mixed types in generated DTOs — acceptable"
bash {baseDir}/scripts/write-memory.sh --section "Accepted Patterns" --entry "Migrations split into schema + backfill steps for zero-downtime"
```

The script creates `.ai/review-memory.md` (and the `.ai/` directory) if they don't exist yet.

### Write policy

- Do **not** write memory during external PR reviews unless the user asks or `review.memory.auto_update: true` is set.
- Propose the entry first ("I can save this to memory — want me to?") when auto_update is false.
- When auto_update is true, write immediately after the review without asking.

See `{baseDir}/references/memory-guide.md` for section reference and quality guidelines.

## Error Handling

1. **Error**: No diff available.
   **Solution**: Ensure changes are staged or specify the branch/commit/PR to compare.

2. **Error**: Config file not found.
   **Solution**: Create `.ai/review.yml` from the example in `{baseDir}/references/config-guide.md`. Review proceeds with defaults if config is absent.

3. **Error**: Test command fails or exits non-zero.
   **Solution**: Check `review.tools.test_command` in config. Include the failure as a P1 finding rather than aborting the review.

4. **Error**: Large diff (1000+ lines).
   **Solution**: Focus on highest-risk files; suggest splitting the PR.

5. **Error**: Memory file missing.
   **Solution**: Review proceeds without memory. Create `.ai/review-memory.md` at any time to enable it.

6. **Error**: Tool not available (e.g., phpstan not installed).
   **Solution**: Skip that tool; note the gap; suggest installing it.

## Examples

### Example 1: Auto — Review Open Changes

**User**: "Review my changes" / "Review my open changes"

```bash
bash {baseDir}/scripts/detect-surface.sh   # auto-detects: staged → unstaged → branch ahead → last commit
# then run the printed command, e.g.: git diff --staged
```

### Example 2: Branch — Review Against a Target

**User**: "Review against develop" / "Review before merging to main"

```bash
bash {baseDir}/scripts/detect-surface.sh --branch develop
# then run: git diff develop...HEAD
```

### Example 3: PR Mode — Full Branch Review

**User**: "Review this PR" / "Review before merging"

```bash
bash {baseDir}/scripts/detect-surface.sh --pr
# auto-detects base (main/master/develop), then: git diff main...HEAD
```

### Example 4: Last N Commits

**User**: "Review the last 3 commits"

```bash
bash {baseDir}/scripts/detect-surface.sh --commits 3
# then run: git diff HEAD~3..HEAD
```

### Example 5: Staged Only

**User**: "Review what I've staged so far"

```bash
bash {baseDir}/scripts/detect-surface.sh --staged
# then run: git diff --staged
```

### Example 6: Review With Tests and Linters

**User**: "Review my changes and run the tests and linters"

1. Detect surface with `detect-surface.sh`.
2. Run `bash {baseDir}/scripts/run-tests.sh`.
3. Run `bash {baseDir}/scripts/run-linters.sh`.
4. Integrate tool output as findings before reporting.

### Example 7: Configure the Review Workflow

**User**: "Set up review config for my Laravel project with PHPStan and Pest"

1. Read `{baseDir}/references/config-guide.md`.
2. Create `.ai/review.yml` with the PHP/Laravel preset.
3. Confirm the config and explain each section.

## Resources

- **Output format + examples**: `{baseDir}/references/output-format.md`
- **Security lens checklist**: `{baseDir}/references/lens-security.md`
- **A11y lens checklist**: `{baseDir}/references/lens-a11y.md`
- **Specialist lens details**: `{baseDir}/references/review-system.md`
- **Config reference**: `{baseDir}/references/config-guide.md`
- **Memory format**: `{baseDir}/references/memory-guide.md`
- **Tools integration**: `{baseDir}/references/tools-guide.md`

## Version History

- **v1.2.0** (2026-06-02): Surface detection modes (auto, branch, PR, commits, staged)
- **v1.1.0** (2026-06-02): Specialist passes (Security, A11y), Reflection/Critic step, structured output format
- **v1.0.0** (2026-06-02): Initial release
