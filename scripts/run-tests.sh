#!/usr/bin/env bash
# Detect project test framework and run tests.
# Supports the standardized tool specification: tools.test.commands.run in .ai/review.yml
# Usage: bash run-tests.sh [--filter <pattern>]
#
# Supported auto-detection: Jest/Vitest/Node test runner (npm/pnpm/yarn/bun), Pest, PHPUnit, cargo test, go test, pytest.

set -euo pipefail

ROOT="${PWD}"
FILTER=""
CONFIG_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter|-f) FILTER="${2:-}"; shift 2 ;;
    --config|-c) CONFIG_ARG="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

CONFIG_FILE=""
CANDIDATE_CONFIGS=()
if [ -n "$CONFIG_ARG" ]; then
  CANDIDATE_CONFIGS+=("$CONFIG_ARG" "$ROOT/$CONFIG_ARG")
fi
CANDIDATE_CONFIGS+=("$ROOT/.ai/review.yml" "$ROOT/.ai/review.yaml" "$HOME/.ai/review.yml" "$HOME/.ai/review.yaml")

for cfg in "${CANDIDATE_CONFIGS[@]}"; do
  if [ -f "$cfg" ]; then
    CONFIG_FILE="$cfg"
    break
  fi
done

CONFIGURED_RUN=""
TEST_ENABLED="true"

if [ -n "$CONFIG_FILE" ]; then
  # Parse tools.test from config using awk
  PARSED=$(awk '
    /^([[:space:]]*)test:/ { in_test=1; indent=length($1); next }
    in_test && /^[[:space:]]*enabled:[[:space:]]*false/ { print "ENABLED=false"; next }
    in_test && /^[[:space:]]*run:[[:space:]]*/ {
      sub(/^[[:space:]]*run:[[:space:]]*/, "");
      sub(/[[:space:]]*#.*/, "");
      gsub(/^[[:space:]]+|[[:space:]]+$/, "");
      if (($0 ~ /^".*"$/) || ($0 ~ /^\047.*\047$/)) {
        $0 = substr($0, 2, length($0) - 2);
      }
      print "RUN=" $0;
      next
    }
    in_test && /^[[:space:]]*[a-zA-Z0-9_-]+:/ && !/^[[:space:]]*(commands|parameters|env):/ {
      curr_indent=length($1);
      if (curr_indent <= indent) in_test=0;
    }
  ' "$CONFIG_FILE" 2>/dev/null || true)

  if echo "$PARSED" | grep -q "ENABLED=false"; then
    echo "[run-tests] Test runner is explicitly disabled (tools.test.enabled: false)."
    exit 0
  fi

  if echo "$PARSED" | grep -q "^RUN="; then
    CONFIGURED_RUN=$(echo "$PARSED" | grep "^RUN=" | head -1 | cut -d'=' -f2-)
  fi
fi

if [ -n "$CONFIGURED_RUN" ]; then
  echo "[run-tests] Using configured tools.test.commands.run: $CONFIGURED_RUN"
  eval "$CONFIGURED_RUN ${FILTER:+"$FILTER"}"
  exit $?
fi

# Node.js — Jest / Vitest / Node test runner with package manager detection (pnpm > yarn > bun > npm)
if [ -f "$ROOT/package.json" ]; then
  PKG_RUNNER="npm"
  if [ -f "$ROOT/pnpm-lock.yaml" ] && command -v pnpm &>/dev/null; then
    PKG_RUNNER="pnpm"
  elif [ -f "$ROOT/yarn.lock" ] && command -v yarn &>/dev/null; then
    PKG_RUNNER="yarn"
  elif ([ -f "$ROOT/bun.lockb" ] || [ -f "$ROOT/bun.lock" ]) && command -v bun &>/dev/null; then
    PKG_RUNNER="bun"
  fi

  HAS_TEST_SCRIPT=false
  if command -v node &>/dev/null && node -e "const pkg=require('./package.json'); process.exit(pkg.scripts && pkg.scripts.test ? 0 : 1)" 2>/dev/null; then
    HAS_TEST_SCRIPT=true
  fi

  if $HAS_TEST_SCRIPT; then
    IS_VITEST=false
    if grep -q -E '"vitest"|"@vitest/' "$ROOT/package.json" 2>/dev/null || [ -f "$ROOT/vitest.config.ts" ] || [ -f "$ROOT/vitest.config.js" ]; then
      IS_VITEST=true
    fi

    echo "[run-tests] Node.js project — running $PKG_RUNNER test"
    if [ -n "$FILTER" ]; then
      if $IS_VITEST; then
        $PKG_RUNNER test "$FILTER"
      else
        if [ "$PKG_RUNNER" = "npm" ]; then
          npm test -- --testPathPattern="$FILTER"
        else
          $PKG_RUNNER test --testPathPattern="$FILTER"
        fi
      fi
    else
      $PKG_RUNNER test
    fi
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
if [ -f "$ROOT/Cargo.toml" ] && command -v cargo &>/dev/null; then
  echo "[run-tests] Rust project — running cargo test"
  cargo test ${FILTER:-}
  exit $?
fi

# Go
if [ -f "$ROOT/go.mod" ] && command -v go &>/dev/null; then
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
echo "  Configure 'tools.test.commands.run' in .ai/review.yml to specify the test command."
exit 1
