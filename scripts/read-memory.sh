#!/usr/bin/env bash
# Read and print the review memory file for the agent to consume.
# Usage: bash read-memory.sh [--file <path>]
#
# Memory file path is resolved from: --file arg > .ai/review.yml > default

ROOT="${PWD}"
MEMORY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file|-f) MEMORY_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Resolve from config if not provided
if [ -z "$MEMORY_FILE" ] && [ -f "$ROOT/.ai/review.yml" ]; then
  MEMORY_FILE=$(grep -E '^\s*file:' "$ROOT/.ai/review.yml" | head -1 | sed 's/.*file:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | tr -d '"' | xargs 2>/dev/null || true)
fi
[ -z "$MEMORY_FILE" ] && MEMORY_FILE=".ai/review-memory.md"

if [ -f "$ROOT/$MEMORY_FILE" ]; then
  echo "# review memory loaded from: $MEMORY_FILE"
  echo ""
  cat "$ROOT/$MEMORY_FILE"
else
  echo "# no review memory found at: $MEMORY_FILE"
  echo "# create .ai/review-memory.md to enable persistent project memory"
fi
