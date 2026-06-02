#!/usr/bin/env bash
# Read and print the review config for the agent to consume.
# Searches for config in priority order and prints the content + resolved path.
# Usage: bash load-config.sh

ROOT="${PWD}"

PATHS=(
  ".ai/review.yml"
  ".ai/review.yaml"
)

for cfg in "${PATHS[@]}"; do
  if [ -f "$ROOT/$cfg" ]; then
    echo "# review config found: $cfg"
    echo ""
    cat "$ROOT/$cfg"
    exit 0
  fi
done

echo "# no review config found — proceeding with auto-detection and default lenses"
exit 0
