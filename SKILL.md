---
name: code-review-agent
description: Context-aware code review with memory, configurable rules, specialist lenses, and automated tool integration. Runs tests, linters, and static analyzers alongside the review. Use when reviewing PRs, diffs, commits, or local changes before merge. Use when inspecting PHP/Laravel, TypeScript/NestJS, Rust, Go, Python, Docker, SQL, or CI changes. Use when running automated checks, creating review rules, or tuning project review memory. Trigger with "review my changes", "review this PR", "check my diff", "run code review", "review before merge".
allowed-tools: "Read,Glob,Grep,Bash(git:*),Bash(rg:*),Bash(npm:*),Bash(npx:*),Bash(yarn:*),Bash(pnpm:*),Bash(composer:*),Bash(pest:*),Bash(phpunit:*),Bash(cargo:*),Bash(go:*),Bash(pytest:*),Bash(phpstan:*),Bash(psalm:*),Bash(semgrep:*),Bash(eslint:*)"
version: "1.0.0"
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

1. Read `AGENTS.md` files if present.
2. Check for config at `.ai/review.yml`, `.ai/review.yaml`, `.codex/review.yml`, or `.codex/review.yaml`.
3. Read memory at `.ai/review-memory.md` or the path configured by `review.memory.file`.
4. Skim `docs/architecture.md`, `docs/conventions.md`, `README.md`, or ADRs when visible.

### Step 2: Identify the Review Surface

- Prefer the user-provided PR, patch, branch, or file list.
- For local work, run `git status --short` then use the relevant `git diff`.
- Compare against a base branch when known; otherwise use staged/unstaged changes.
- Do not review unrelated dirty work unless explicitly asked.

```bash
git diff --staged           # staged changes
git diff main...HEAD        # branch diff
git show <sha>              # specific commit
```

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

### Step 5: Apply Specialist Lenses

- **Correctness**: broken contracts, edge cases, error handling, state transitions, backward compatibility.
- **Security**: authz/authn, injection, XSS, SSRF, secrets, path traversal, unsafe deserialization.
- **Data**: transaction scope, migrations, indexes, nullable/unique constraints, rollback paths.
- **Performance**: N+1 queries, unbounded loops, memory pressure, caching, concurrency.
- **Architecture**: layering, DDD boundaries, dependency direction, domain logic placement.
- **Tests**: missing tests for changed behavior, brittle assertions, coverage gaps.
- **Operations**: Docker, CI, env vars, observability, migration/deploy sequencing.

Use `{baseDir}/references/review-system.md` for detailed specialist lens guidance and stack-specific prompts.

### Step 6: Consolidate and Report

- Deduplicate findings across lenses and tools.
- Prioritize by impact and likelihood.
- Ground each finding in a specific file and line when available.
- Explain the risk and provide a concrete fix or validation path.
- Skip style nits unless they hide real maintainability or correctness risk.

## Output

Lead with findings ordered by severity:

- `P0`: data loss, security breach, production outage, or hard merge blocker.
- `P1`: likely bug, serious security/performance regression, or broken core workflow.
- `P2`: meaningful maintainability, architecture, test, or edge-case risk.
- `P3`: low-risk improvement, only worth mentioning on an otherwise clean review.

After findings, include open questions only when they affect the result. If no findings, say so clearly and note any residual confidence gap.

## Memory Handling

- Read memory before reviewing when it exists.
- Raise sensitivity to recurring project issues, accepted decisions, and known false positives.
- Do not write memory during external PR reviews unless the user asks or `review.memory.auto_update: true` is set.
- Propose a memory entry when a review reveals a useful recurring lesson.

See `{baseDir}/references/memory-guide.md` for memory format and management.

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

### Example 1: Review Staged Changes

**User**: "Review my changes"

1. Run `git diff --staged` to get the diff.
2. Load `.ai/review.yml` and `.ai/review-memory.md` if present.
3. Classify changed files, apply lenses, use `rg` for context.
4. Output findings ordered P0 → P3.

### Example 2: Review a Feature Branch Before Merging

**User**: "Review feature/auth-refactor before merging"

1. Run `git diff main...feature/auth-refactor`.
2. Load project context and memory.
3. Apply security and correctness lenses with increased sensitivity on auth files.
4. Run affected test command if configured.

### Example 3: Review With Tests and Linters

**User**: "Review my changes and run the tests and linters"

1. Identify diff, load context.
2. Run `bash {baseDir}/scripts/run-tests.sh` — auto-detects framework.
3. Run `bash {baseDir}/scripts/run-linters.sh` — auto-detects installed tools.
4. Integrate tool output as findings before reporting.

### Example 4: Configure the Review Workflow

**User**: "Set up review config for my Laravel project with PHPStan and Pest"

1. Read `{baseDir}/references/config-guide.md` for the config reference.
2. Create `.ai/review.yml` with the PHP/Laravel preset and the user's customizations.
3. Confirm the config is valid and explain each section.

## Resources

- **Config reference**: `{baseDir}/references/config-guide.md`
- **Memory format**: `{baseDir}/references/memory-guide.md`
- **Tools integration**: `{baseDir}/references/tools-guide.md`
- **Specialist lens details**: `{baseDir}/references/review-system.md`
- **Run tests**: `{baseDir}/scripts/run-tests.sh`
- **Run linters**: `{baseDir}/scripts/run-linters.sh`

## Version History

- **v1.0.0** (2026-06-02): Initial release
