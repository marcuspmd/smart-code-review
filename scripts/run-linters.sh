#!/usr/bin/env bash
# Detect and run linters and static analyzers for the project.
# Usage: bash run-linters.sh [--path <target-path>]
#
# Supports: ESLint, PHPStan, Psalm, cargo clippy, go vet, mypy, ruff, semgrep.
# Reads static_analysis list from .ai/review.yml when present.

set -euo pipefail

ROOT="${PWD}"
TARGET=""
FOUND=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path|-p) TARGET="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

run_tool() {
  local label="$1"; shift
  echo ""
  echo "── $label ─────────────────────────────────────"
  "$@" || true
  FOUND=1
}

# ── JavaScript / TypeScript — ESLint ─────────────────────────────────────────
if [ -f "$ROOT/package.json" ]; then
  HAS_ESLINT=false
  for cfg in .eslintrc.js .eslintrc.cjs .eslintrc.json eslint.config.js eslint.config.mjs eslint.config.cjs; do
    [ -f "$ROOT/$cfg" ] && HAS_ESLINT=true && break
  done
  if $HAS_ESLINT && ([ -f "$ROOT/node_modules/.bin/eslint" ] || command -v eslint &>/dev/null); then
    TARGET_ARG="${TARGET:-src/}"
    [ -d "$ROOT/$TARGET_ARG" ] || TARGET_ARG="."
    run_tool "ESLint" npx eslint --ext .ts,.tsx,.js,.jsx "$TARGET_ARG"
  fi
fi

# ── PHP — PHPStan ─────────────────────────────────────────────────────────────
if [ -f "$ROOT/vendor/bin/phpstan" ]; then
  TARGET_ARG="${TARGET:-src/}"
  [ -d "$ROOT/$TARGET_ARG" ] || TARGET_ARG="app/"
  run_tool "PHPStan" ./vendor/bin/phpstan analyse --no-progress --error-format=table "$TARGET_ARG"
fi

# ── PHP — Psalm ──────────────────────────────────────────────────────────────
if [ -f "$ROOT/vendor/bin/psalm" ]; then
  run_tool "Psalm" ./vendor/bin/psalm --show-info=true
fi

# ── Rust — cargo clippy ──────────────────────────────────────────────────────
if [ -f "$ROOT/Cargo.toml" ]; then
  run_tool "Cargo Clippy" cargo clippy -- -D warnings
fi

# ── Go — go vet ──────────────────────────────────────────────────────────────
if [ -f "$ROOT/go.mod" ]; then
  run_tool "Go Vet" go vet ./...
  if command -v staticcheck &>/dev/null; then
    run_tool "Staticcheck" staticcheck ./...
  fi
fi

# ── Python — ruff ────────────────────────────────────────────────────────────
if ([ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/setup.py" ]) && command -v ruff &>/dev/null; then
  TARGET_ARG="${TARGET:-.}"
  run_tool "Ruff" ruff check "$TARGET_ARG"
fi

# ── Python — mypy ────────────────────────────────────────────────────────────
if ([ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/setup.py" ]) && command -v mypy &>/dev/null; then
  TARGET_ARG="${TARGET:-src/}"
  [ -d "$ROOT/$TARGET_ARG" ] || TARGET_ARG="."
  run_tool "Mypy" mypy "$TARGET_ARG"
fi

# ── Semgrep — multi-language security ────────────────────────────────────────
if command -v semgrep &>/dev/null; then
  TARGET_ARG="${TARGET:-.}"
  run_tool "Semgrep" semgrep --config auto --quiet "$TARGET_ARG"
fi

echo ""

if [ "$FOUND" -eq 0 ]; then
  echo "[run-linters] No linters detected."
  echo "  Install one of: ESLint, PHPStan, Psalm, cargo clippy, go vet, ruff, mypy, semgrep."
  exit 1
fi

echo "[run-linters] Done."
