#!/usr/bin/env bash
# Execute a configured lifecycle hook for smart-code-review.
#
# Supported hooks:
#   pre_review    - Runs before code analysis begins
#   post_review   - Runs after review report is generated
#   on_blocker    - Runs when P0 / Critical blocker findings are discovered
#   on_approved   - Runs when review verdict is APPROVE / clean
#
# Usage:
#   bash run-hook.sh <hook_name> [--verdict <APPROVE|REQUEST_CHANGES>] [--p0-count <N>]

set -euo pipefail

ROOT="${PWD}"
HOOK_NAME="${1:-}"

if [ -z "$HOOK_NAME" ]; then
  echo "Usage: bash run-hook.sh <pre_review|post_review|on_blocker|on_approved> [options]" >&2
  exit 1
fi
shift

VERDICT=""
P0_COUNT="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verdict|-v)  VERDICT="${2:-}"; shift 2 ;;
    --p0-count|-p) P0_COUNT="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# Discover config file
CONFIG_FILE=""
for cfg in "$ROOT/.ai/review.yml" "$ROOT/.ai/review.yaml" "$HOME/.ai/review.yml"; do
  if [ -f "$cfg" ]; then
    CONFIG_FILE="$cfg"
    break
  fi
done

if [ -z "$CONFIG_FILE" ]; then
  exit 0
fi

# Extract hook command
HOOK_CMD=""
if command -v python3 &>/dev/null; then
  HOOK_CMD="$(python3 - "$CONFIG_FILE" "$HOOK_NAME" << 'PYEOF'
import sys, re

cfg_path = sys.argv[1]
hook_key = sys.argv[2]

try:
    with open(cfg_path, 'r', encoding='utf-8') as f:
        content = f.read()

    m = re.search(r'^\s*' + re.escape(hook_key) + r':\s*["\']?([^"\'\n\r]+)["\']?', content, re.MULTILINE)
    if m:
        val = m.group(1).strip()
        if val:
            print(val)
except Exception:
    pass
PYEOF
  )"
fi

if [ -z "$HOOK_CMD" ]; then
  exit 0
fi

echo "[hook] Executing '$HOOK_NAME': $HOOK_CMD"

export CODE_REVIEW_HOOK="$HOOK_NAME"
export CODE_REVIEW_VERDICT="$VERDICT"
export CODE_REVIEW_P0_COUNT="$P0_COUNT"

eval "$HOOK_CMD"

