# Review Memory Guide

Review memory stores project-specific knowledge that persists across review sessions. It makes the reviewer more accurate on every subsequent review by suppressing false positives and enforcing local team conventions.

## Memory File Location

- Default: `.ai/review-memory.md`
- Custom path: configured via `review.memory.file` in `.ai/review.yml`

## Memory File Format

```markdown
# Review Memory

## Architecture

- The project uses DDD-style boundaries; keep domain logic out of controllers.
- Prefer constructor injection over service locator patterns.

## Recurring Issues

- Reports in the analytics module are prone to N+1 queries due to missing eager loading.
- Transaction boundaries are often too wide around external HTTP calls.

## Accepted Patterns

- Migrations may be split into schema and backfill steps for zero-downtime deploys.
- LegacyReportBuilder uses service locator intentionally (scheduled for removal in Q3).

## False Positives

- Generated API clients in src/generated/ intentionally violate local naming conventions.
- PHPStan level 8 flags mixed types in generated DTO classes — acceptable.

## Custom Rules

- All POST endpoints must be idempotent or document why they are not.
```

---

## Memory Lifecycle: Add, Edit, Remove, and Compact

Over time, codebases evolve: libraries are upgraded, legacy patterns are finally deleted, and certain rules become obsolete or already enforced by linters. Leaving dead rules in memory bloats the context and can lead to incorrect reviews.

The `manage-memory.sh` (and `write-memory.sh`) script provides full lifecycle operations:

### 1. Adding Entries (`--add` or `--entry`)

```bash
# Add a new architectural invariant
bash {baseDir}/scripts/manage-memory.sh --add --section "Architecture" --entry "Domain/ must not import from Infrastructure/"

# Or via write-memory.sh (delegates to manage-memory.sh)
bash {baseDir}/scripts/write-memory.sh --section "Recurring Issues" --entry "Missing with('items') in Order queries"
```
*Entries are automatically deduplicated — exact matches will not be inserted twice.*

### 2. Editing / Replacing Outdated Entries (`--replace`)

When a convention changes or an accepted pattern is updated:

```bash
# Replace an old rule with the updated standard
bash {baseDir}/scripts/manage-memory.sh --replace "LegacyReportBuilder uses service locator" --with "LegacyReportBuilder removed; use ReportAction pipeline"

# Target a specific section for replacement
bash {baseDir}/scripts/manage-memory.sh --replace "Zod v3 uuid" --with "Use z.uuid() from Zod v4" --section "Custom Rules"
```

### 3. Removing Obsolete Entries (`--remove` or `--delete`)

When a rule is no longer true (e.g. module deleted, linter now handles it, or rule deprecated):

```bash
# Remove an entry by substring match
bash {baseDir}/scripts/manage-memory.sh --remove "LegacyReportBuilder"

# Remove only from a specific section
bash {baseDir}/scripts/manage-memory.sh --remove "mixed return types" --section "False Positives"
```

### 4. Inspecting Memory Stats (`--stats`)

Check the size and entry distribution across sections:

```bash
bash {baseDir}/scripts/manage-memory.sh --stats
```
Output:
```text
# Review Memory Stats (.ai/review-memory.md)
  - Architecture: 4 entries
  - Recurring Issues: 6 entries
  - Accepted Patterns: 2 entries
  - False Positives: 3 entries
  - Custom Rules: 5 entries
Total entries: 20
```

### 5. Compacting & Pruning (`--compact`)

When the memory file grows long or contains redundant items:

```bash
bash {baseDir}/scripts/manage-memory.sh --compact
```
What `--compact` does:
1. Normalizes formatting, bullet points, and blank lines across all sections.
2. Removes duplicate entries across sections.
3. Checks if the total entry count exceeds 30 items. If so, emits a notice recommending AI synthesis.

---

## When to Prune and Compact

**Remove an entry when**:
- The deprecated module or class referenced has been deleted from the repository.
- A linter rule or CI check was added that already catches the issue automatically.
- The exception expired (e.g., "acceptable until Q3" and it is now Q4).
- Two entries say almost the same thing (consolidate into one crisp rule).

**Ask the AI to Synthesize / Compact**:
If `manage-memory.sh --stats` shows more than **30–40 entries**, prompt the agent:
> *"Reorganize and compact my .ai/review-memory.md: merge overlapping rules, remove anything that looks obsolete, and keep it crisp."*

The agent reads the existing entries, groups related rules into bulleted summaries, and rewrites the file cleanly.

---

## AI Memory Compaction Prompt & Protocol

When instructed to compact, clean up, or reorganize project memory (or when triggered autonomously because memory exceeded 30 entries), the AI agent must follow this exact reasoning protocol:

### The Compaction System Prompt

```text
You are acting as the Memory Curator for this codebase. Your goal is to compress, clean, and organize the project review memory (.ai/review-memory.md) without losing durable architectural decisions, critical bug lessons, or valid false-positive exceptions.

Follow this 4-step execution plan:

1. Inventory & Codebase Grounding:
   - Read all entries across all sections.
   - For entries referencing specific classes, modules, files, or packages, verify if they still exist in the repository (using Glob or Grep).
   - If a referenced entity has been deleted or fully replaced, mark that entry as OBSOLETE (Prune).

2. Pruning & Filtering (Drop Criteria):
   - Expired Exceptions: Remove entries mentioning temporary allowances whose timeframe or milestone has passed (e.g. "approved until migration in Q3").
   - Generic Boilerplate: Remove generic best practices that are already standard language knowledge or covered by the active linter suite (e.g., "always validate user input", "avoid unused imports").
   - Fixed One-Off Bugs: Remove bug notes that were specific to an isolated historical PR rather than an ongoing risk pattern.

3. Semantic Clustering & Merging (Consolidate Criteria):
   - Find entries within the same section that address the same underlying concern (e.g., three separate notes about N+1 queries in report endpoints).
   - Consolidate them into a single, comprehensive, actionable rule that names the affected domain and the preferred fix pattern.

4. Markdown Formatting & Reporting:
   - Ensure all items start with `- ` and are placed under their canonical headings:
     ## Architecture
     ## Recurring Issues
     ## Accepted Patterns
     ## False Positives
     ## Custom Rules
   - Present a clear summary table showing:
     * Number of entries before vs after
     * List of pruned (removed) obsolete entries with brief reason
     * List of merged entries
   - If user explicitly requested compaction, overwrite the file cleanly. If running as an autonomous recommendation, ask confirmation before applying.
```

### Example: Before vs After Compaction

#### Before:
```markdown
## Recurring Issues
- Missing with('items') on Order in analytics reports causes N+1 queries.
- Analytics report queries are slow because items relationship is not eager loaded.
- In CustomerReportAction, remember to eager load customer addresses.
- Fixed typo in invoice calculation formula in PR #104.
```

#### After:
```markdown
## Recurring Issues
- Analytics and export reports (Order, Customer) frequently miss eager loading (`with('items')`, `with('addresses')`), causing severe N+1 query bottlenecks.
```
*(Pruned the 2 redundant variations and the one-off historical typo fix; kept 1 high-impact rule).*

---

## Agent Autonomous Operations

The review agent can and should execute these commands autonomously whenever relevant:

1. **User asks in natural language**:
   - *"Save to memory that we use pnpm, not npm"* $\rightarrow$ Agent runs `manage-memory.sh --add --section "Architecture" --entry "..."`
   - *"Remove the rule about LegacyService"* $\rightarrow$ Agent runs `manage-memory.sh --remove "LegacyService"`
   - *"Update the memory: we now use Zod v4 instead of v3"* $\rightarrow$ Agent runs `manage-memory.sh --replace "Zod v3" --with "Zod v4"`
   - *"Compact our memory"* $\rightarrow$ Agent runs `manage-memory.sh --compact` and prints the resulting stats.
2. **Post-Review Confirmation**:
   - When the agent proposes new recurring lessons at the end of a review and you reply with *"save them"* or *"yes"*, the agent executes `manage-memory.sh --add` for each approved item immediately.
3. **Dead Code Cleanup**:
   - When reviewing a PR that deletes legacy files or removes deprecated exceptions, the agent inspects `review-memory.md` to see if those patterns were tracked, and removes them or alerts you to prune them.

---

## Auto-Update Behavior

| Config setting | Behavior |
|---|---|
| `auto_update: false` (default) | Skill proposes memory entries for user review before writing |
| `auto_update: true` | Skill appends useful lessons after each review automatically |

Use `auto_update: false` on shared repos to keep memory changes auditable via git PRs.

## Memory and Sensitive Information

**Never store** secrets, credentials, tokens, or PII in memory files.

Memory files should be committed to version control so all reviewers share the same project knowledge.
