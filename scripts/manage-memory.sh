#!/usr/bin/env bash
# Manage project review memory: add, edit, remove, inspect stats, or compact.
# Works with Python 3 (prefer) or pure Bash/awk fallback (zero external dependencies).
#
# Usage:
#   bash manage-memory.sh --add --section "Architecture" --entry "DDD rules..."
#   bash manage-memory.sh --remove "old rule text" [--section "Architecture"]
#   bash manage-memory.sh --replace "old rule text" --with "new rule text" [--section "Architecture"]
#   bash manage-memory.sh --compact
#   bash manage-memory.sh --stats
#
# Valid sections: Architecture | Recurring Issues | Accepted Patterns | False Positives | Custom Rules

set -euo pipefail

ROOT="${PWD}"
ACTION="add"
SECTION=""
ENTRY=""
FIND_TEXT=""
REPLACE_WITH=""
MEMORY_FILE=""
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --add|-a)        ACTION="add"; shift ;;
    --remove|-d|--delete) ACTION="remove"; FIND_TEXT="${2:-}"; shift 2 ;;
    --replace|-r|--edit)  ACTION="replace"; FIND_TEXT="${2:-}"; shift 2 ;;
    --with|-w)       REPLACE_WITH="${2:-}"; shift 2 ;;
    --compact|-c|--prune) ACTION="compact"; shift ;;
    --stats)         ACTION="stats"; shift ;;
    --section|-s)    SECTION="${2:-}"; shift 2 ;;
    --entry|-e)      ENTRY="${2:-}"; shift 2 ;;
    --file|-f)       MEMORY_FILE="${2:-}"; shift 2 ;;
    --config)        CONFIG_FILE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -n "$ENTRY" ] && [ "$ACTION" = "add" ]; then
  ACTION="add"
fi

# Resolve memory file path from config if not provided
if [ -z "$MEMORY_FILE" ]; then
  CANDIDATE_CONFIGS=()
  if [ -n "$CONFIG_FILE" ]; then
    CANDIDATE_CONFIGS+=("$CONFIG_FILE" "$ROOT/$CONFIG_FILE")
  fi
  CANDIDATE_CONFIGS+=("$ROOT/.ai/review.yml" "$ROOT/.ai/review.yaml")

  for cfg in "${CANDIDATE_CONFIGS[@]}"; do
    if [ -f "$cfg" ]; then
      FOUND_CFG=$(grep -E '^\s*file:' "$cfg" | head -1 | sed 's/.*file:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | tr -d '"\047' | xargs 2>/dev/null || true)
      if [ -n "$FOUND_CFG" ]; then
        MEMORY_FILE="$FOUND_CFG"
        break
      fi
    fi
  done
fi
[ -z "$MEMORY_FILE" ] && MEMORY_FILE=".ai/review-memory.md"

if [[ "$MEMORY_FILE" == /* ]]; then
  MEMORY_PATH="$MEMORY_FILE"
elif [[ "$MEMORY_FILE" == ~* ]]; then
  MEMORY_PATH="${MEMORY_FILE/#\~/$HOME}"
else
  MEMORY_PATH="$ROOT/$MEMORY_FILE"
fi

# Ensure memory file exists
if [ ! -f "$MEMORY_PATH" ]; then
  if [ "$ACTION" = "remove" ] || [ "$ACTION" = "replace" ] || [ "$ACTION" = "stats" ]; then
    echo "[manage-memory] Memory file not found at: $MEMORY_FILE"
    exit 0
  fi
  mkdir -p "$(dirname "$MEMORY_PATH")"
  cat > "$MEMORY_PATH" << 'TEMPLATE'
# Review Memory

## Architecture

## Recurring Issues

## Accepted Patterns

## False Positives

## Custom Rules
TEMPLATE
  echo "[manage-memory] Initialized $MEMORY_FILE"
fi

# If python3 is available, use it for clean Markdown AST parsing and manipulation
if command -v python3 &>/dev/null; then
  python3 - "$MEMORY_PATH" "$ACTION" "$SECTION" "$ENTRY" "$FIND_TEXT" "$REPLACE_WITH" << 'PYEOF'
import sys

filepath     = sys.argv[1]
action       = sys.argv[2]
target_sec   = sys.argv[3].strip()
entry        = sys.argv[4].strip()
find_text    = sys.argv[5].strip()
replace_with = sys.argv[6].strip()

default_order = ["Architecture", "Recurring Issues", "Accepted Patterns", "False Positives", "Custom Rules"]

def read_memory(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    lines = content.splitlines()
    sections = {}
    current_sec = None
    header_lines = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('## '):
            current_sec = stripped[3:].strip()
            if current_sec not in sections:
                sections[current_sec] = []
        elif current_sec is not None:
            if stripped:
                sections[current_sec].append(stripped)
        else:
            header_lines.append(line)
    return header_lines, sections

def write_memory(path, header_lines, sections):
    output = []
    top = '\n'.join(header_lines).strip()
    if top:
        output.append(top)
        output.append("")
    else:
        output.append("# Review Memory")
        output.append("")

    seen_keys = set()
    for key in default_order:
        seen_keys.add(key)
        output.append(f"## {key}")
        items = sections.get(key, [])
        for it in items:
            clean = it if it.startswith('- ') else f"- {it}"
            output.append(clean)
        output.append("")

    for key, items in sections.items():
        if key not in seen_keys:
            output.append(f"## {key}")
            for it in items:
                clean = it if it.startswith('- ') else f"- {it}"
                output.append(clean)
            output.append("")

    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(output).rstrip() + '\n')

def clean_item(text):
    return text.lstrip('-*• \t').strip()

header_lines, sections = read_memory(filepath)

if action == "add":
    if not entry:
        print("ERROR: --entry is required for add")
        sys.exit(1)
    sec = target_sec if target_sec else "Recurring Issues"
    if sec not in sections:
        sections[sec] = []

    norm_entry = clean_item(entry).lower().rstrip('.')
    for item in sections[sec]:
        if clean_item(item).lower().rstrip('.') == norm_entry:
            print(f"[manage-memory] Entry already exists in '{sec}' (skipped duplicate)")
            sys.exit(0)

    sections[sec].append(f"- {clean_item(entry)}")
    write_memory(filepath, header_lines, sections)
    print(f"[manage-memory] Added to '{sec}': {clean_item(entry)}")

elif action == "remove":
    if not find_text:
        print("ERROR: text to remove is required (--remove <text>)")
        sys.exit(1)
    norm_find = find_text.lower()
    removed_count = 0
    sections_to_search = [target_sec] if target_sec and target_sec in sections else list(sections.keys())
    for sec in sections_to_search:
        remaining = []
        for item in sections[sec]:
            cleaned = clean_item(item)
            if norm_find in cleaned.lower():
                print(f"[manage-memory] Removed from '{sec}': {cleaned}")
                removed_count += 1
            else:
                remaining.append(item)
        sections[sec] = remaining

    if removed_count == 0:
        print(f"[manage-memory] No entry found matching: '{find_text}'")
    else:
        write_memory(filepath, header_lines, sections)
        print(f"[manage-memory] Total removed: {removed_count}")

elif action == "replace":
    if not find_text:
        print("ERROR: target text is required (--replace <old_text>)")
        sys.exit(1)
    new_text = replace_with if replace_with else entry
    if not new_text:
        print("ERROR: replacement text is required (--with <new_text>)")
        sys.exit(1)
    norm_find = find_text.lower()
    replaced_count = 0
    sections_to_search = [target_sec] if target_sec and target_sec in sections else list(sections.keys())
    for sec in sections_to_search:
        new_items = []
        for item in sections[sec]:
            cleaned = clean_item(item)
            if norm_find in cleaned.lower():
                print(f"[manage-memory] Replaced in '{sec}':\n  - Old: {cleaned}\n  + New: {clean_item(new_text)}")
                new_items.append(f"- {clean_item(new_text)}")
                replaced_count += 1
            else:
                new_items.append(item)
        sections[sec] = new_items

    if replaced_count == 0:
        print(f"[manage-memory] No entry found matching: '{find_text}'")
    else:
        write_memory(filepath, header_lines, sections)
        print(f"[manage-memory] Total replaced: {replaced_count}")

elif action == "compact":
    total_before = sum(len(items) for items in sections.values())
    deduped_count = 0
    for sec in sections:
        seen = set()
        compact_items = []
        for item in sections[sec]:
            cleaned = clean_item(item)
            key = cleaned.lower().rstrip('.')
            if key not in seen:
                seen.add(key)
                compact_items.append(f"- {cleaned}")
            else:
                deduped_count += 1
        sections[sec] = compact_items

    write_memory(filepath, header_lines, sections)
    total_after = sum(len(items) for items in sections.values())
    print(f"[manage-memory] Memory compacted.")
    print(f"  Entries before: {total_before}")
    print(f"  Entries after:  {total_after} (removed {deduped_count} duplicates)")
    if total_after > 30:
        print(f"  [Notice] Memory has {total_after} entries. Consider asking the agent to synthesize older rules.")

elif action == "stats":
    total = 0
    print(f"# Review Memory Stats ({filepath})")
    for sec in default_order:
        items = sections.get(sec, [])
        total += len(items)
        print(f"  - {sec}: {len(items)} entries")
    for sec, items in sections.items():
        if sec not in default_order:
            total += len(items)
            print(f"  - {sec} (custom): {len(items)} entries")
    print(f"Total entries: {total}")
PYEOF

else
  # POSIX / Bash fallback when Python is not installed
  case "$ACTION" in
    add)
      SEC="${SECTION:-Recurring Issues}"
      if ! grep -q "^## ${SEC}$" "$MEMORY_PATH"; then
        printf '\n## %s\n' "$SEC" >> "$MEMORY_PATH"
      fi
      if grep -qiF "$ENTRY" "$MEMORY_PATH"; then
        echo "[manage-memory] Entry already exists in $MEMORY_FILE (skipped duplicate)"
      else
        awk -v sec="## $SEC" -v entry="- $ENTRY" '
          in_sec && /^## / { print entry; print ""; in_sec=0 }
          { print }
          $0 == sec       { in_sec=1 }
          END             { if (in_sec) { print entry; print "" } }
        ' "$MEMORY_PATH" > "${MEMORY_PATH}.tmp" && mv "${MEMORY_PATH}.tmp" "$MEMORY_PATH"
        echo "[manage-memory] Added to '${SEC}': ${ENTRY}"
      fi
      ;;
    remove)
      if [ -z "$FIND_TEXT" ]; then
        echo "ERROR: --remove requires a search pattern"
        exit 1
      fi
      grep -viF "$FIND_TEXT" "$MEMORY_PATH" > "${MEMORY_PATH}.tmp" && mv "${MEMORY_PATH}.tmp" "$MEMORY_PATH"
      echo "[manage-memory] Removed entries matching: '$FIND_TEXT'"
      ;;
    replace)
      NEW_TEXT="${REPLACE_WITH:-$ENTRY}"
      sed -i.bak "s|${FIND_TEXT}|${NEW_TEXT}|g" "$MEMORY_PATH" 2>/dev/null || sed -i "" "s|${FIND_TEXT}|${NEW_TEXT}|g" "$MEMORY_PATH"
      rm -f "${MEMORY_PATH}.bak"
      echo "[manage-memory] Replaced occurrences of '$FIND_TEXT'"
      ;;
    stats)
      echo "# Review Memory Stats ($MEMORY_FILE)"
      grep -E '^\- ' "$MEMORY_PATH" | wc -l | sed 's/^/  Total rules: /'
      ;;
    compact)
      echo "[manage-memory] Compact requested. (For advanced semantic clustering, the AI agent updates the file directly)."
      ;;
  esac
fi

echo "[manage-memory] File: $MEMORY_FILE"
