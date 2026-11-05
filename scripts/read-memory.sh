#!/usr/bin/env bash
# Read and print the review memory file for the agent to consume.
# Usage: bash read-memory.sh [--file <path>] [--config <path>]
#
# Memory file path is resolved from: --file arg > config file (file: ...) > default (.ai/review-memory.md)

ROOT="${PWD}"
MEMORY_FILE=""
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file|-f)   MEMORY_FILE="$2"; shift 2 ;;
    --config|-c) CONFIG_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Resolve from config if not provided
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

# Expand ~ or absolute paths
if [[ "$MEMORY_FILE" == /* ]]; then
  MEMORY_PATH="$MEMORY_FILE"
elif [[ "$MEMORY_FILE" == ~* ]]; then
  MEMORY_PATH="${MEMORY_FILE/#\~/$HOME}"
else
  MEMORY_PATH="$ROOT/$MEMORY_FILE"
fi

if [ -f "$MEMORY_PATH" ]; then
  echo "# review memory loaded from: $MEMORY_FILE"
  echo ""
  cat "$MEMORY_PATH"
else
  echo "# no review memory found at: $MEMORY_FILE"
  echo "# create .ai/review-memory.md to enable persistent project memory"
fi
