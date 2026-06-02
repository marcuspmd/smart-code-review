#!/usr/bin/env bash
# Detect project test framework and run tests.
# Usage: bash run-tests.sh [--filter <pattern>]
#
# Supports: Jest/Vitest (npm), Pest, PHPUnit, cargo test, go test, pytest.
# Override auto-detection by setting REVIEW_TEST_CMD in .ai/review.yml.

set -euo pipefail

ROOT="${PWD}"
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter|-f) FILTER="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# Read test_command from .ai/review.yml if present
if [ -f "$ROOT/.ai/review.yml" ] && command -v grep &>/dev/null; then
  CONFIGURED=$(grep -E '^\s*test_command:' "$ROOT/.ai/review.yml" | sed 's/.*test_command:\s*//' | tr -d '"' | xargs 2>/dev/null || true)
  if [ -n "$CONFIGURED" ] && [ "$CONFIGURED" != "null" ]; then
    echo "[run-tests] Using configured test_command: $CONFIGURED"
    eval "$CONFIGURED ${FILTER:+"$FILTER"}"
    exit $?
  fi
fi

# Node.js — Jest / Vitest via npm scripts
if [ -f "$ROOT/package.json" ]; then
  if command -v node &>/dev/null && node -e "require('./package.json').scripts && process.exit(require('./package.json').scripts.test ? 0 : 1)" 2>/dev/null; then
    echo "[run-tests] Node.js project — running npm test"
    npm test ${FILTER:+-- --testPathPattern="$FILTER"}
    exit $?
  fi
fi

# PHP — Pest (preferred over PHPUnit)
if [ -f "$ROOT/vendor/bin/pest" ]; then
  echo "[run-tests] Pest detected — running ./vendor/bin/pest"
  ./vendor/bin/pest ${FILTER:+--filter="$FILTER"}
  exit $?
fi

if [ -f "$ROOT/vendor/bin/phpunit" ]; then
  echo "[run-tests] PHPUnit detected — running ./vendor/bin/phpunit"
  ./vendor/bin/phpunit ${FILTER:+--filter="$FILTER"}
  exit $?
fi

# Rust
if [ -f "$ROOT/Cargo.toml" ]; then
  echo "[run-tests] Rust project — running cargo test"
  cargo test ${FILTER:-}
  exit $?
fi

# Go
if [ -f "$ROOT/go.mod" ]; then
  echo "[run-tests] Go project — running go test ./..."
  go test ./... ${FILTER:+-run "$FILTER"}
  exit $?
fi

# Python — pytest
if [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/setup.py" ] || [ -f "$ROOT/pytest.ini" ] || [ -f "$ROOT/setup.cfg" ]; then
  if command -v pytest &>/dev/null; then
    echo "[run-tests] Python project — running pytest"
    pytest ${FILTER:+-k "$FILTER"}
    exit $?
  fi
fi

echo "[run-tests] ERROR: No recognized test framework found."
echo "  Set 'review.tools.test_command' in .ai/review.yml to specify the test command."
exit 1
