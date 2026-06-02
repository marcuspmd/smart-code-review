#!/usr/bin/env bash
# Append an entry to a section in the review memory file.
# Creates the file and section if they don't exist.
#
# Usage:
#   bash write-memory.sh --section "Recurring Issues" --entry "Reports prone to N+1 queries"
#   bash write-memory.sh --section "Architecture" --entry "DDD: Domain/ must not import Infrastructure/"
#   bash write-memory.sh --section "False Positives" --entry "PHPStan flags mixed in generated DTOs — acceptable"
#   bash write-memory.sh --section "Accepted Patterns" --entry "Migrations split into schema + backfill steps"
#   bash write-memory.sh --section "Custom Rules" --entry "All POST endpoints must be idempotent"
#
# Valid sections: Architecture | Recurring Issues | Accepted Patterns | False Positives | Custom Rules

ROOT="${PWD}"
SECTION=""
ENTRY=""
MEMORY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --section|-s) SECTION="$2"; shift 2 ;;
    --entry|-e)   ENTRY="$2";   shift 2 ;;
    --file|-f)    MEMORY_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Validate required args
if [ -z "$ENTRY" ]; then
  echo "ERROR: --entry is required"
  echo "Usage: bash write-memory.sh --section <section> --entry <text>"
  exit 1
fi
[ -z "$SECTION" ] && SECTION="Recurring Issues"

# Resolve memory file path
if [ -z "$MEMORY_FILE" ] && [ -f "$ROOT/.ai/review.yml" ]; then
  MEMORY_FILE=$(grep -E '^\s*file:' "$ROOT/.ai/review.yml" | head -1 | sed 's/.*file:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | tr -d '"' | xargs 2>/dev/null || true)
fi
[ -z "$MEMORY_FILE" ] && MEMORY_FILE=".ai/review-memory.md"

MEMORY_PATH="$ROOT/$MEMORY_FILE"

# Create the file with default structure if it doesn't exist
if [ ! -f "$MEMORY_PATH" ]; then
  mkdir -p "$(dirname "$MEMORY_PATH")"
  cat > "$MEMORY_PATH" << 'TEMPLATE'
# Review Memory

## Architecture

## Recurring Issues

## Accepted Patterns

## False Positives

## Custom Rules
TEMPLATE
  echo "[write-memory] Created $MEMORY_FILE"
fi

# Ensure section exists in file
if ! grep -q "^## ${SECTION}$" "$MEMORY_PATH"; then
  printf '\n## %s\n' "$SECTION" >> "$MEMORY_PATH"
fi

# Insert entry after section heading using Python3 (prefer) or awk (fallback)
if command -v python3 &>/dev/null; then
  python3 - "$MEMORY_PATH" "$SECTION" "$ENTRY" << 'PYEOF'
import sys

filepath = sys.argv[1]
section  = sys.argv[2]
entry    = sys.argv[3]
heading  = f"## {section}"
bullet   = f"- {entry}"

with open(filepath, 'r') as f:
    lines = f.readlines()

in_section = False
insert_at  = len(lines)

for i, line in enumerate(lines):
    stripped = line.rstrip('\n')
    if stripped == heading:
        in_section = True
        continue
    if in_section:
        # Insert before the next section heading
        if stripped.startswith('## '):
            insert_at = i
            break
        # Keep track of last content line so we place entry right after it
        if stripped.strip():
            insert_at = i + 1

lines.insert(insert_at, bullet + '\n')

with open(filepath, 'w') as f:
    f.writelines(lines)
PYEOF
else
  # awk fallback: append entry after the target section heading
  awk -v sec="## $SECTION" -v entry="- $ENTRY" '
    in_sec && /^## / { print entry; in_sec=0 }
    { print }
    $0 == sec       { in_sec=1 }
    END             { if (in_sec) print entry }
  ' "$MEMORY_PATH" > "${MEMORY_PATH}.tmp" && mv "${MEMORY_PATH}.tmp" "$MEMORY_PATH"
fi

echo "[write-memory] Added to '${SECTION}': ${ENTRY}"
echo "[write-memory] File: $MEMORY_FILE"
