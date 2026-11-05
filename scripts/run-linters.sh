#!/usr/bin/env bash
# Detect and run linters and static analyzers for the project.
# Supports the standardized tool specification: tools.<name>.commands.run and tools.<name>.enabled in .ai/review.yml
# Usage:
#   bash run-linters.sh [--path <target-path>] [--files <file1,file2,...>]
#
# Supported tools: ESLint, PHPStan, Psalm, cargo clippy, go vet, staticcheck, mypy, ruff, semgrep, sonar.

set -euo pipefail

ROOT="${PWD}"
TARGET=""
FILES_CSV=""
CONFIG_ARG=""
FOUND=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path|-p)   TARGET="${2:-}"; shift 2 ;;
    --files|-f)  FILES_CSV="${2:-}"; shift 2 ;;
    --config|-c) CONFIG_ARG="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

CHANGED_FILES=()
if [ -n "$FILES_CSV" ]; then
  IFS=',' read -ra CHANGED_FILES <<< "$FILES_CSV"
fi

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

# Helper to check if a tool is enabled and whether it has a custom commands.run
get_tool_info() {
  local tool_name="$1"
  if [ -z "$CONFIG_FILE" ]; then
    echo "STATUS=auto"
    return
  fi

  awk -v tool="$tool_name" '
    BEGIN { in_tools=0; in_target=0; enabled="auto"; custom_run="" }
    /^([[:space:]]*)tools:/ { in_tools=1; next }
    in_tools && $0 ~ "^[[:space:]]+" tool ":" { in_target=1; next }
    in_target && /^[[:space:]]*enabled:[[:space:]]*false/ { enabled="false" }
    in_target && /^[[:space:]]*enabled:[[:space:]]*true/ { enabled="true" }
    in_target && /^[[:space:]]*run:[[:space:]]*/ {
      sub(/^[[:space:]]*run:[[:space:]]*/, "");
      sub(/[[:space:]]*#.*/, "");
      gsub(/^[[:space:]]+|[[:space:]]+$/, "");
      if (($0 ~ /^".*"$/) || ($0 ~ /^\047.*\047$/)) {
        $0 = substr($0, 2, length($0) - 2);
      }
      custom_run=$0;
    }
    in_target && /^[[:space:]]*[a-zA-Z0-9_-]+:/ && !/^[[:space:]]*(commands|parameters|env):/ {
      in_target=0
    }
    END {
      print "ENABLED=" enabled;
      print "CUSTOM_RUN=" custom_run;
    }
  ' "$CONFIG_FILE" 2>/dev/null || echo "ENABLED=auto"
}

is_tool_enabled() {
  local tool_name="$1"
  local info
  info=$(get_tool_info "$tool_name")
  if echo "$info" | grep -q "ENABLED=false"; then
    return 1
  fi
  return 0
}

get_custom_run() {
  local tool_name="$1"
  local info
  info=$(get_tool_info "$tool_name")
  echo "$info" | grep "^CUSTOM_RUN=" | cut -d'=' -f2-
}

run_tool() {
  local label="$1"; shift
  echo ""
  echo "── $label ─────────────────────────────────────"
  "$@" || true
  FOUND=1
}

# ── JavaScript / TypeScript — ESLint ─────────────────────────────────────────
if is_tool_enabled "eslint" && [ -f "$ROOT/package.json" ]; then
  CUSTOM_CMD=$(get_custom_run "eslint")
  if [ -n "$CUSTOM_CMD" ]; then
    run_tool "ESLint (configured)" eval "$CUSTOM_CMD"
  else
    HAS_FLAT_CONFIG=false
    HAS_LEGACY_CONFIG=false
    for cfg in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts; do
      [ -f "$ROOT/$cfg" ] && HAS_FLAT_CONFIG=true && break
    done
    if ! $HAS_FLAT_CONFIG; then
      for cfg in .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yaml .eslintrc.yml .eslintrc; do
        [ -f "$ROOT/$cfg" ] && HAS_LEGACY_CONFIG=true && break
      done
    fi

    if ($HAS_FLAT_CONFIG || $HAS_LEGACY_CONFIG) && ([ -f "$ROOT/node_modules/.bin/eslint" ] || command -v eslint &>/dev/null); then
      JS_FILES=()
      if [ ${#CHANGED_FILES[@]} -gt 0 ]; then
        for f in "${CHANGED_FILES[@]}"; do
          if [[ "$f" =~ \.(ts|tsx|js|jsx|mjs|cjs)$ ]] && [ -f "$ROOT/$f" ]; then
            JS_FILES+=("$f")
          fi
        done
      fi

      if [ ${#CHANGED_FILES[@]} -gt 0 ] && [ ${#JS_FILES[@]} -eq 0 ]; then
        :
      elif [ ${#JS_FILES[@]} -gt 0 ]; then
        run_tool "ESLint (changed files)" npx eslint "${JS_FILES[@]}"
      else
        TARGET_ARG="${TARGET:-src/}"
        [ -d "$ROOT/$TARGET_ARG" ] || TARGET_ARG="."
        if $HAS_FLAT_CONFIG; then
          run_tool "ESLint" npx eslint "$TARGET_ARG"
        else
          run_tool "ESLint" npx eslint --ext .ts,.tsx,.js,.jsx "$TARGET_ARG"
        fi
      fi
    fi
  fi
fi

# ── PHP — PHPStan ─────────────────────────────────────────────────────────────
if is_tool_enabled "phpstan" && [ -f "$ROOT/vendor/bin/phpstan" ]; then
  CUSTOM_CMD=$(get_custom_run "phpstan")
  if [ -n "$CUSTOM_CMD" ]; then
    run_tool "PHPStan (configured)" eval "$CUSTOM_CMD"
  else
    PHP_FILES=()
    if [ ${#CHANGED_FILES[@]} -gt 0 ]; then
      for f in "${CHANGED_FILES[@]}"; do
        if [[ "$f" =~ \.php$ ]] && [ -f "$ROOT/$f" ]; then
          PHP_FILES+=("$f")
        fi
      done
    fi

    if [ ${#CHANGED_FILES[@]} -gt 0 ] && [ ${#PHP_FILES[@]} -eq 0 ]; then
      :
    elif [ ${#PHP_FILES[@]} -gt 0 ]; then
      run_tool "PHPStan (changed files)" ./vendor/bin/phpstan analyse --no-progress --error-format=table "${PHP_FILES[@]}"
    else
      TARGET_ARG="${TARGET:-src/}"
      [ -d "$ROOT/$TARGET_ARG" ] || TARGET_ARG="app/"
      run_tool "PHPStan" ./vendor/bin/phpstan analyse --no-progress --error-format=table "$TARGET_ARG"
    fi
  fi
fi

# ── PHP — Psalm ──────────────────────────────────────────────────────────────
if is_tool_enabled "psalm" && [ -f "$ROOT/vendor/bin/psalm" ]; then
  run_tool "Psalm" ./vendor/bin/psalm --show-info=true
fi

# ── Rust — cargo clippy ──────────────────────────────────────────────────────
if is_tool_enabled "clippy" || is_tool_enabled "cargo-clippy"; then
  if [ -f "$ROOT/Cargo.toml" ] && command -v cargo &>/dev/null; then
    run_tool "Cargo Clippy" cargo clippy -- -D warnings
  fi
fi

# ── Go — go vet & staticcheck ────────────────────────────────────────────────
if [ -f "$ROOT/go.mod" ] && command -v go &>/dev/null; then
  if is_tool_enabled "govet" || is_tool_enabled "go-vet"; then
    run_tool "Go Vet" go vet ./...
  fi
  if is_tool_enabled "staticcheck" && command -v staticcheck &>/dev/null; then
    run_tool "Staticcheck" staticcheck ./...
  fi
fi

# ── Python — ruff ────────────────────────────────────────────────────────────
if is_tool_enabled "ruff" && ([ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/setup.py" ] || [ -f "$ROOT/ruff.toml" ]) && command -v ruff &>/dev/null; then
  CUSTOM_CMD=$(get_custom_run "ruff")
  if [ -n "$CUSTOM_CMD" ]; then
    run_tool "Ruff (configured)" eval "$CUSTOM_CMD"
  else
    PY_FILES=()
    if [ ${#CHANGED_FILES[@]} -gt 0 ]; then
      for f in "${CHANGED_FILES[@]}"; do
        if [[ "$f" =~ \.py$ ]] && [ -f "$ROOT/$f" ]; then
          PY_FILES+=("$f")
        fi
      done
    fi

    if [ ${#CHANGED_FILES[@]} -gt 0 ] && [ ${#PY_FILES[@]} -eq 0 ]; then
      :
    elif [ ${#PY_FILES[@]} -gt 0 ]; then
      run_tool "Ruff (changed files)" ruff check "${PY_FILES[@]}"
    else
      TARGET_ARG="${TARGET:-.}"
      run_tool "Ruff" ruff check "$TARGET_ARG"
    fi
  fi
fi

# ── Python — mypy ────────────────────────────────────────────────────────────
if is_tool_enabled "mypy" && ([ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/setup.py" ] || [ -f "$ROOT/mypy.ini" ]) && command -v mypy &>/dev/null; then
  CUSTOM_CMD=$(get_custom_run "mypy")
  if [ -n "$CUSTOM_CMD" ]; then
    run_tool "Mypy (configured)" eval "$CUSTOM_CMD"
  else
    PY_FILES=()
    if [ ${#CHANGED_FILES[@]} -gt 0 ]; then
      for f in "${CHANGED_FILES[@]}"; do
        if [[ "$f" =~ \.py$ ]] && [ -f "$ROOT/$f" ]; then
          PY_FILES+=("$f")
        fi
      done
    fi

    if [ ${#CHANGED_FILES[@]} -gt 0 ] && [ ${#PY_FILES[@]} -eq 0 ]; then
      :
    elif [ ${#PY_FILES[@]} -gt 0 ]; then
      run_tool "Mypy (changed files)" mypy "${PY_FILES[@]}"
    else
      TARGET_ARG="${TARGET:-src/}"
      [ -d "$ROOT/$TARGET_ARG" ] || TARGET_ARG="."
      run_tool "Mypy" mypy "$TARGET_ARG"
    fi
  fi
fi

# ── Semgrep — multi-language security ────────────────────────────────────────
if is_tool_enabled "semgrep" && command -v semgrep &>/dev/null; then
  if [ ${#CHANGED_FILES[@]} -gt 0 ]; then
    run_tool "Semgrep (changed files)" semgrep --config auto --quiet "${CHANGED_FILES[@]}"
  else
    TARGET_ARG="${TARGET:-.}"
    run_tool "Semgrep" semgrep --config auto --quiet "$TARGET_ARG"
  fi
fi

echo ""

if [ "$FOUND" -eq 0 ]; then
  echo "[run-linters] No linters executed."
  echo "  Configure 'tools.<tool_name>.enabled: true' in .ai/review.yml or install standard linters (ruff, mypy, eslint, etc.)."
  exit 0
fi

echo "[run-linters] Done."
