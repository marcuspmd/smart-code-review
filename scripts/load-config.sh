#!/usr/bin/env bash
# Read and print the review config for the agent to consume.
# Merges global config (~/.ai/review.yml) with project config (.ai/review.yml).
# When both exist, prints both with labeled sections — the model applies the merge rules.
# Usage: bash load-config.sh [--global <path>]
#
# Merge rules (applied by the model, not this script):
#   Scalars (language, test_command, etc.): project wins
#   Lists (priorities, always_check, custom_rules, extra_bash, etc.): additive, global first + project (dedup)
#   tools.mcps: additive; if same server in both, project entry takes precedence
#   tools.extra_skills: additive, global first + project

ROOT="${PWD}"
GLOBAL_CONFIG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global|-g) GLOBAL_CONFIG="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# Expand ~ in path
if [ -n "$GLOBAL_CONFIG" ]; then
  GLOBAL_CONFIG="${GLOBAL_CONFIG/#\~/$HOME}"
fi

PROJECT_PATHS=(
  ".ai/review.yml"
  ".ai/review.yaml"
)

FOUND_PROJECT=""
for cfg in "${PROJECT_PATHS[@]}"; do
  if [ -f "$ROOT/$cfg" ]; then
    FOUND_PROJECT="$ROOT/$cfg"
    break
  fi
done

FOUND_GLOBAL=""
if [ -n "$GLOBAL_CONFIG" ] && [ -f "$GLOBAL_CONFIG" ]; then
  FOUND_GLOBAL="$GLOBAL_CONFIG"
fi

# Neither found
if [ -z "$FOUND_GLOBAL" ] && [ -z "$FOUND_PROJECT" ]; then
  echo "# no review config found — proceeding with auto-detection and default lenses"
  exit 0
fi

# Global only
if [ -n "$FOUND_GLOBAL" ] && [ -z "$FOUND_PROJECT" ]; then
  echo "# review config: global only ($FOUND_GLOBAL)"
  echo ""
  cat "$FOUND_GLOBAL"
  exit 0
fi

# Project only
if [ -z "$FOUND_GLOBAL" ] && [ -n "$FOUND_PROJECT" ]; then
  echo "# review config: project only ($FOUND_PROJECT)"
  echo ""
  cat "$FOUND_PROJECT"
  exit 0
fi

# Both found — print both with labels; agent applies merge rules above
echo "# review config: global ($FOUND_GLOBAL) + project ($FOUND_PROJECT)"
echo "# merge rule: project scalars win; lists are additive (global first, then project, deduped)"
echo ""
echo "# --- GLOBAL CONFIG ($FOUND_GLOBAL) ---"
cat "$FOUND_GLOBAL"
echo ""
echo "# --- PROJECT CONFIG ($FOUND_PROJECT) ---"
cat "$FOUND_PROJECT"
