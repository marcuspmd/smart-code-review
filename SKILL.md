---
name: smart-code-review
description: Context-aware code review with memory, configurable rules, specialist lenses, and automated tool integration. Runs tests, linters, and static analyzers alongside the review. Use when reviewing PRs, diffs, commits, or local changes before merge. Use when inspecting PHP/Laravel, TypeScript/NestJS, Rust, Go, Python, Docker, SQL, SonarQube, or CI changes. Use when running automated checks, creating review rules, or tuning project review memory. Trigger with "review my changes", "review my open changes", "review this PR", "review against develop", "review against main", "review the last N commits", "check my diff", "run code review", "review before merge".
allowed-tools: "Read,Glob,Grep,Bash(bash:*),Bash(git:*),Bash(rg:*),Bash(npm:*),Bash(npx:*),Bash(yarn:*),Bash(pnpm:*),Bash(bun:*),Bash(composer:*),Bash(pest:*),Bash(phpunit:*),Bash(cargo:*),Bash(go:*),Bash(pytest:*),Bash(ruff:*),Bash(mypy:*),Bash(phpstan:*),Bash(psalm:*),Bash(semgrep:*),Bash(eslint:*),Bash(sonar-scanner:*),Bash(docker:*),Bash(make:*),Bash(curl:*),mcp__*,mcp_*"
version: "1.5.0"
---

# Smart Code Review

Context-aware AI code review with project configuration, persistent memory, specialist lenses, and automated tool integration.

## Overview

This skill runs a structured code review by loading project context (config, memory, rules, architecture docs), identifying the diff surface, applying specialist lenses (correctness, security, data, performance, architecture, tests, ops), running relevant tools, and producing prioritized findings.

Responds in the user's language unless repository conventions require otherwise.

> **Path Note**: `{baseDir}` represents the installation path of this skill. If invoking from within the skill directory, relative paths (`./scripts/...` and `./references/...`) can be used directly.

## How to Invoke

**Natural language** — the skill activates automatically from these phrases:

| What the user says | Review surface used |
|---|---|
| "review my changes" / "review my open changes" | Auto: staged → unstaged → untracked → branch ahead → last commit |
| "review against develop" / "review against main" | Branch diff: current branch vs named target |
| "review this PR" / "review before merging" | PR mode: branch vs auto-detected base |
| "review the last 3 commits" | Last N commits on current branch |
| "review what I staged" | Staged changes only |
| "review and run tests" / "review and run linters" / "run sonar" | Auto surface + tool execution |
| "/smart-code-review init" / "init review" | Intelligent agent-guided setup (surveys repo, detects linters/tests, writes tailored configs) |
| "install review hooks" / "setup git hooks" | Installs git pre-commit & pre-push hooks (`install-hooks.sh`) |
| "save this to memory" / "add rule to review memory" | Memory addition (`manage-memory.sh --add`) |
| "remove rule from memory" / "forget rule about X" | Memory removal (`manage-memory.sh --remove`) |
| "update memory rule X with Y" | Memory edit/replacement (`manage-memory.sh --replace`) |
| "compact review memory" / "clean up memory" | Memory pruning & deduplication (`manage-memory.sh --compact`) |

**Slash commands**: `/smart-code-review` (or `/code-review-agent`), `/smart-code-review init`

## Prerequisites

**Required**: Git repository with staged, committed, or branch-level changes.

**Optional configuration files**:
- `~/.ai/review.yml` — global defaults (merged with project config; project wins on conflict)
- `.ai/review.yml` or `.ai/review.yaml` (or custom path via `--config <path>`) — review config (lenses, tools, priorities, ignore rules, custom rules)
- `.ai/review-memory.md` — persistent review memory (recurring issues, accepted patterns, false positives)
- `.ai/review-rules.md` — project-specific freeform guidelines and architecture constraints in Markdown
- `sonar-project.properties` — optional SonarQube / SonarCloud project configuration

See `{baseDir}/references/config-guide.md` for the full configuration reference.

## Instructions

### Step 0: Pre-Review Hooks

If configured in `.ai/review.yml`, run the pre-review lifecycle hook:
```bash
bash {baseDir}/scripts/run-hook.sh pre_review
```

### Step 1: Load Project Context

1. Load config — merges global (`~/.ai/review.yml`) with project (`.ai/review.yml`) and prints the result:

```bash
bash {baseDir}/scripts/load-config.sh --global ~/.ai/review.yml
# Or pass --config <path> to override project config:
# bash {baseDir}/scripts/load-config.sh --config .ai/custom-review.yml
```

When both configs exist, the output contains two labeled sections (`# --- GLOBAL CONFIG ---` and `# --- PROJECT CONFIG ---`). Apply these merge rules:
- Scalar values (`language`, `auto_update`, etc.): project wins
- List values (`priorities`, `always_check`, `ignore.paths`, `custom_rules`, `extra_bash`, `extra_skills`): additive — global items first, then project items, deduplicated
- `tools.<name>`: project tool definition overrides global; commands, env, and parameters merged
- `tools.mcps`: additive; if same `server` in both, project entry takes precedence

2. Load memory (guaranteed — prints content or reports missing):

```bash
bash {baseDir}/scripts/read-memory.sh
```

3. Read `.ai/review-rules.md` if present in the repository root for team-specific rules.
4. Read `AGENTS.md` files if present.
5. Skim `docs/architecture.md`, `docs/conventions.md`, `README.md`, or ADRs when visible.
6. Discover peer skills — look for other installed skills that may enrich the review:

```bash
# Pass extra paths from tools.extra_skills if present in the loaded config
bash {baseDir}/scripts/discover-skills.sh --extra-paths "<extra_paths_if_configured>"
```

For each skill found: read its SKILL.md to extract lens definitions, checklists, or rule sets relevant to the current review surface. Incorporate those items as additional checklist entries in the relevant Step 5 specialist passes. **Do not invoke the skill** — only read its file content. If no skills are found, skip silently.

### Step 2: Identify the Review Surface & Context Protection

Run the surface detector — it resolves the correct mode, prints stats, and outputs the exact `git diff` command to use:

```bash
# Auto mode (priority: staged → unstaged → untracked → branch ahead of base → last commit)
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

#### Context Protection for Large Diffs:
1. **Lockfiles Excluded**: The detector automatically appends exclusions for `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `composer.lock`, and `Cargo.lock`. Never dump raw lockfile changes into context.
2. **Diff Size Triage**:
   - If the detector reports that the diff contains **over 500 lines changed** or **more than 10 files**:
     - First, run `git diff --stat` to identify the high-risk files (controllers, domain logic, migrations, security configs).
     - Read the diff in focused batches or file-by-file (e.g. `git diff <base>...HEAD -- path/to/file.ts`) rather than dumping a massive multi-thousand line diff into context at once.
     - Deprioritize or skim boilerplate/generated files.

### Step 3: Build Review Profile

- Detect language, framework, storage layer, test framework, runtime, and deploy surface.
- Classify changed files by role: controller, service, entity, migration, SQL, test, Docker, CI, config, docs.
- Map each file class to the most relevant lenses.
- Check the resolved config for:
  - `tools.extra_bash` — note additional analysis tools available for Step 4 (e.g., `docker:*`, `kubectl:*`, `make:*`)
  - `tools.mcps` — note which post-review MCP actions are configured for Step 7b
  - `tools.extra_skills` — note extra skill paths loaded in Step 1
  - Standardized tools declared under `tools.<tool>` (e.g., `tools.sonar`, `tools.test`, `tools.test-e2e`) — inspect `commands` (run, up, health, down), `env`, and `parameters` (diff_scoped, timeout, min_coverage).

### Step 4: Run Tools When Useful

Tools increase confidence — they do not replace analysis. Run only what is cheap and relevant unless the user asked for more.

```bash
# Search for callers of a changed function
rg "functionName" --type ts

# Run affected tests (uses config or auto-detection)
bash {baseDir}/scripts/run-tests.sh

# Run linters and static analysis (scoped to changed files or project)
bash {baseDir}/scripts/run-linters.sh

# Target specific changed files for linters
bash {baseDir}/scripts/run-linters.sh --files "path/to/file1.ts,path/to/file2.ts"
```

#### Standardized Tool Lifecycle Execution (`tools.<name>`)

When structured tools are configured in `.ai/review.yml` (e.g. `sonar`, `test`, `test-e2e`, `security`) or requested by the user:
1. **Health & Readiness Check**:
   - If `commands.health` is defined (e.g. `curl -f http://localhost:9000/api/system/status`), run it first.
   - If healthy, proceed directly.
   - If offline or fails, execute `commands.up` (e.g. `make sonar-up` or `docker compose up -d`), wait for readiness, and then proceed.
2. **Environment Resolution**:
   - Resolve variables declared in `env:`. If referenced as `${VAR_NAME}`, read from the environment or local `.env` file (never commit plaintext secrets in config).
3. **Execute Primary Command**:
   - Run `commands.run` (e.g. `make sonar-scan`, `make test`, `make test-e2e`).
4. **Parameter Interpretation & AI In-Context Diff-Scoping**:
   - If `parameters.diff_scoped: true`: Query the tool's findings API or CLI output. In-context, intersect each finding with the exact files and lines touched in this review's `git diff` (Step 2). Drop findings on untouched lines as pre-existing technical debt.
   - If `parameters.min_coverage` is defined: Verify if test coverage reported meets the threshold; if below, raise a P1 finding.
5. **Teardown (Optional)**:
   - If the user requests cleanup or shutdown after the review, execute `commands.down` (e.g. `make sonar-down`).

For per-stack tool commands, SonarQube/SonarCloud setup, and integration rules, see `{baseDir}/references/tools-guide.md`.

### Step 5: Run Specialist Passes

Run each pass relevant to the review profile. Collect findings independently per pass before merging:

- **Security Pass** — run on every diff touching endpoints, auth, input/output, file ops, crypto, or sessions:
  Read `{baseDir}/references/lens-security.md` and apply all relevant checklist items.
- **Data & Migrations Pass** — run on diffs with migrations, SQL, ORM entities, transactions, or indexes:
  Read `{baseDir}/references/lens-data.md` and check for locks, zero-downtime expand/contract, N+1 queries, and rollback methods.
- **Correctness & Concurrency Pass** — run on logic changes, race conditions, edge cases, error handling, and state machines:
  Read `{baseDir}/references/lens-correctness.md` and check for race conditions, unhandled exceptions, and boundaries.
- **Performance Pass** — run on loops, heavy queries, cache operations, serialization, and high-throughput paths:
  Read `{baseDir}/references/lens-performance.md` and check for unbounded queries, memory leaks, and blocking I/O.
- **Architecture Pass** — run on module additions, refactors, domain logic, and interface changes:
  Read `{baseDir}/references/lens-architecture.md` and check for DDD/layer violations, coupling, and circular dependencies.
  *Plan Alignment Check*: If an implementation plan exists (`.claude/plans/*.md`, `plans/*.md`, `docs/plans/*.md`), check if the code adheres to the approved scope or introduced unauthorized scope creep / unapproved R2-R3 artifacts.
- **Tests Pass** — missing tests for changed behavior, assertions that don't actually test the change, brittle fixtures.
- **Operations Pass** — Docker image pinning, secrets in CI, env var gaps, health checks, deploy sequencing.
- **A11y Pass** — run only if the diff touches HTML, JSX/TSX, CSS, or ARIA:
  Read `{baseDir}/references/lens-a11y.md` and apply WCAG 2.1 AA checklist items.

See `{baseDir}/references/review-system.md` for stack-specific prompts per pass.

### Step 6: Reflection / Critic Pass

Before reporting, challenge every finding collected in Step 5. For each finding, ask:

1. **In the diff?** — Is this line actually changed in this diff, or is it pre-existing code?
2. **In scope?** — Is the file excluded by `review.ignore.paths` in config?
3. **In memory?** — Does the memory file list this as a known false positive or accepted pattern?
4. **Concrete?** — Is there a specific file+line reference and a concrete fix? Speculative findings without a fix belong at P3 or get dropped.
5. **Severity accurate?** — Does the impact in this codebase match the P0–P3 scale? Do not inherit severity from tool output.
6. **Line number verified?** — **CRITICAL**: Do not rely purely on arithmetic from git diff `@@ -a,b +c,d @@` headers. Verify the exact line number by viewing the file context to ensure `path/to/file:line` is accurate.

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

### Step 7b: Post-Review MCP Actions

If the resolved config contains `tools.mcps`, offer the configured post-review actions after the review report is complete.

**Only execute an MCP action when all three conditions are met:**
1. The config has a `tools.mcps` entry for the server.
2. The `use_for` list includes the action type.
3. The user confirms — or `auto_post: true` is set on that entry.

**P0 findings → create issue/ticket** (if `create_issue` or `create_ticket` is in `use_for`):
- Offer to create one issue/ticket per P0 finding.
- Title: the finding title. Body: file+line, one-sentence risk, concrete fix.
- MCP tool name patterns: `mcp__<server>__create_issue` (Claude) or `mcp_<server>_create_issue` (Universal).

**PR comment** (if `add_pr_comment` is in `use_for`):
- Offer to post the full review output as a PR comment.
- MCP tool name patterns: `mcp__<server>__add_pr_comment` (Claude) or `mcp_<server>_add_pr_comment` (Universal).

**Graceful degradation**: if an MCP tool call fails or the server is unavailable, append a note to the output and continue. The review report is always the primary deliverable — never abort or re-run the review due to MCP failures.

See `{baseDir}/references/tools-guide.md` for MCP tool name resolution and config examples.

### Step 7c: Execute Post-Review Hooks

Run configured lifecycle hooks based on final review findings:
```bash
# Post-review hook (runs for all completed reviews)
bash {baseDir}/scripts/run-hook.sh post_review --verdict "<VERDICT>"

# Blocker vs Approved hook
if [ "<P0_COUNT>" -gt 0 ] || [ "<VERDICT>" = "REQUEST_CHANGES" ]; then
  bash {baseDir}/scripts/run-hook.sh on_blocker --verdict "<VERDICT>" --p0-count "<P0_COUNT>"
else
  bash {baseDir}/scripts/run-hook.sh on_approved --verdict "<VERDICT>" --p0-count 0
fi
```

---

## Setup & Initialization Mode (`/smart-code-review init`)

When triggered via `/smart-code-review init` or requests like *"init review"*, *"configure smart-code-review"*, the agent executes the **Intelligent Initialization Protocol** (detailed in `{baseDir}/references/init-workflow.md`):

1. **Step 1: Codebase Survey**: Inspect project root (`composer.json`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Dockerfile`, CI files) to detect language, frameworks, test runners, and static linters (PHPStan, ESLint, Ruff, Mypy, Go Vet).
2. **Step 2: Contextual Interview**: Present the detected stack in chat and ask up to 3 targeted calibration questions (Report Language, Test & Linter commands, SonarQube usage, and Git hooks).
3. **Step 3: Generate Intelligent Files**:
   - Write `.ai/review.yml` tailored with the project's actual test and lint commands.
   - Write `.ai/review-rules.md` with stack-specific code quality and architecture constraints.
   - Write `.ai/review-memory.md` seeded with detected conventions and recurring patterns.
4. **Step 4: Install Git Hooks**: Offer to run `bash {baseDir}/scripts/install-hooks.sh` to install pre-commit and pre-push hooks.

*(For automated / headless environments, `bash {baseDir}/scripts/init.sh --defaults` can be invoked directly).*

## Memory Lifecycle & Management

Memory stores persistent project knowledge across reviews. The agent must proactively keep memory up-to-date and compact.

### 1. Reading Memory
Always run this at the start of every review (Step 1):
```bash
bash {baseDir}/scripts/read-memory.sh
```

### 2. Adding Memory Entries
When a recurring bug pattern, convention, or false positive is identified:
```bash
bash {baseDir}/scripts/manage-memory.sh --add --section "Recurring Issues" --entry "Reports prone to N+1 queries in analytics module"
# or write-memory.sh:
bash {baseDir}/scripts/write-memory.sh --section "Architecture" --entry "DDD: Domain/ must not import from Infrastructure/"
```

### 3. Editing & Replacing Outdated Rules
When a convention changes or an existing rule needs clarification:
```bash
bash {baseDir}/scripts/manage-memory.sh --replace "<old rule text>" --with "<updated rule text>" [--section "Architecture"]
```

### 4. Removing Obsolete Rules
When a pattern is deleted, deprecated, or superseded by a linter rule:
```bash
bash {baseDir}/scripts/manage-memory.sh --remove "<text to match>" [--section "False Positives"]
```

### 5. Inspecting Stats & Compacting
Inspect entry counts and compact duplicate/redundant entries:
```bash
# Check memory entry count per section
bash {baseDir}/scripts/manage-memory.sh --stats

# Compact and deduplicate memory entries
bash {baseDir}/scripts/manage-memory.sh --compact
```

### 6. AI-Assisted Memory Synthesis & Compaction Protocol
When memory exceeds **30 entries**, becomes cluttered with overlapping rules, or the user requests compaction, the agent must follow the **Memory Compaction Protocol** in `{baseDir}/references/memory-guide.md`:
1. **Inventory & Verify**: Grep/Glob codebase to check if referenced classes/modules still exist.
2. **Prune**: Drop expired exceptions, generic linter redundancies, and fixed one-off bug notes.
3. **Consolidate**: Merge overlapping rules within the same section into unified, actionable statements.
4. **Report & Update**: Present the before/after statistics and table of changes, then save the streamlined `.ai/review-memory.md`.

### 7. Agent Autonomous Execution Protocol

The AI agent has full authority and tools to invoke these memory scripts directly:

- **Direct User Instructions**: When the user asks to save, update, delete, or clean up memory (e.g., *"remember this"*, *"remove that rule"*, *"clean memory"*), the agent **must execute the corresponding script immediately** (`manage-memory.sh --add/--replace/--remove/--compact`) instead of telling the user to run it manually.
- **Confirmation After Review**: When `auto_update: false` and the agent proposed a memory entry at the end of a review, if the user replies with consent (*"yes, save it"*, *"approved"*, *"write that to memory"*), the agent **must immediately invoke** `bash {baseDir}/scripts/manage-memory.sh --add ...`.
- **Automatic Pruning on Code Deletion**: If the reviewed diff deletes a legacy class/module that was previously whitelisted in `review-memory.md` (e.g. under `Accepted Patterns` or `False Positives`), the agent should execute or propose `manage-memory.sh --remove "<module_name>"` to keep the memory synchronized with the current codebase.
- **Compaction on Demand**: When instructed to *"organize"*, *"compact"*, or *"clean up"* memory, the agent runs `manage-memory.sh --compact` or reads the memory file, synthesizes the bullet points, and writes the cleaner, streamlined version.

See `{baseDir}/references/memory-guide.md` for quality guidelines and lifecycle details.

## Error Handling

1. **Error**: No diff available.
   **Solution**: Ensure changes are staged or specify the branch/commit/PR to compare.
2. **Error**: Config file not found.
   **Solution**: Create `.ai/review.yml` from the example in `{baseDir}/references/config-guide.md`. Review proceeds with defaults if config is absent.
3. **Error**: Test command fails or exits non-zero.
   **Solution**: Check `review.tools.test.commands.run` in config. Include the failure as a P1 finding rather than aborting the review.
4. **Error**: Large diff (1000+ lines).
   **Solution**: Use `git diff --stat`, prioritize critical files, review in batches, and recommend splitting the PR.
5. **Error**: Memory file missing.
   **Solution**: Review proceeds without memory. Create `.ai/review-memory.md` at any time to enable it.
6. **Error**: Tool not available (e.g., phpstan or sonar not installed).
   **Solution**: Skip that tool; note the gap in metadata; suggest installing or running it via Docker.
7. **Error**: Global config not found at `~/.ai/review.yml`.
   **Solution**: Review proceeds using only project config.
8. **Error**: MCP tool call fails or server is not available.
   **Solution**: Skip the MCP action; append a note to the review output. The review report is complete without post-review actions.
9. **Error**: Discovered skill has no readable SKILL.md or no lens definitions.
   **Solution**: Skip that skill silently.

## Resources

- **Output format + examples**: `{baseDir}/references/output-format.md`
- **Security lens**: `{baseDir}/references/lens-security.md`
- **Data & migrations lens**: `{baseDir}/references/lens-data.md`
- **Correctness & concurrency lens**: `{baseDir}/references/lens-correctness.md`
- **Performance lens**: `{baseDir}/references/lens-performance.md`
- **Architecture lens**: `{baseDir}/references/lens-architecture.md`
- **Accessibility lens**: `{baseDir}/references/lens-a11y.md`
- **Specialist lens details & prompts**: `{baseDir}/references/review-system.md`
- **Config reference**: `{baseDir}/references/config-guide.md`
- **Migration & Upgrade guide**: `{baseDir}/references/migration-guide.md`
- **Memory guide (Add, Edit, Remove, Compact)**: `{baseDir}/references/memory-guide.md`
- **Tools & SonarQube guide**: `{baseDir}/references/tools-guide.md`

## Version History

- **v1.5.0** (2026-11-05): Breaking Change: Standardized Tool Specification (`tools.<name>` with `commands`, `env`, `parameters`). Removed legacy flat `test_command` and `static_analysis` shortcuts. Added full Migration Guide.
- **v1.4.1** (2026-11-05): Added SonarQube/SonarCloud Docker & CLI integration, full memory lifecycle management (edit, remove, stats, compact), and memory bloat prevention.
- **v1.4.0** (2026-11-05): Added dedicated lenses for Data, Correctness, Performance, and Architecture. Added Python & Go presets and security checklists. Fixed macOS Bash 3.2 compatibility, ESLint Flat Config, and untracked file detection. Added diff context protection and exact line verification.
- **v1.3.0** (2026-06-02): Global config (`~/.ai/review.yml`), MCP post-review actions (Step 7b), peer skill discovery (Step 1), `extra_bash`/`mcps`/`extra_skills` config fields
- **v1.2.0** (2026-06-02): Surface detection modes (auto, branch, PR, commits, staged)
- **v1.1.0** (2026-06-02): Specialist passes (Security, A11y), Reflection/Critic step, structured output format
- **v1.0.0** (2026-06-02): Initial release
