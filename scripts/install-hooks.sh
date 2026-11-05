#!/usr/bin/env bash
# Install Git hooks for automated pre-commit and pre-push code reviews.
#
# Usage:
#   bash install-hooks.sh [--pre-commit] [--pre-push]

set -euo pipefail

ROOT="${PWD}"
GIT_DIR="$ROOT/.git"

if [ ! -d "$GIT_DIR" ]; then
  echo "Error: Not a git repository ($GIT_DIR not found)." >&2
  exit 1
fi

HOOKS_DIR="$GIT_DIR/hooks"
mkdir -p "$HOOKS_DIR"

PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"
PRE_PUSH_HOOK="$HOOKS_DIR/pre-push"

echo "Installing smart-code-review git hooks in $HOOKS_DIR..."

# 1. Pre-commit hook: Staged changes linter & diff sanity
if [ -f "$PRE_COMMIT_HOOK" ]; then
  if grep -q "smart-code-review" "$PRE_COMMIT_HOOK"; then
    echo "smart-code-review hook already installed in $PRE_COMMIT_HOOK"
  else
    cat >> "$PRE_COMMIT_HOOK" << 'HOOK_EOF'

# --- smart-code-review hook ---
STAGED_FILES=$(git diff --cached --name-only || true)
if [ -n "$STAGED_FILES" ]; then
  echo "[smart-code-review] Checking staged files before commit..."
  if [ -f "scripts/run-linters.sh" ]; then
    bash scripts/run-linters.sh --files "$(echo "$STAGED_FILES" | paste -sd, -)"
  fi
fi
# --- end smart-code-review hook ---
HOOK_EOF
    echo "Appended smart-code-review to existing $PRE_COMMIT_HOOK"
  fi
else
  cat > "$PRE_COMMIT_HOOK" << 'HOOK_EOF'
#!/usr/bin/env bash
set -e

# --- smart-code-review hook ---
STAGED_FILES=$(git diff --cached --name-only || true)
if [ -n "$STAGED_FILES" ]; then
  echo "[smart-code-review] Checking staged files before commit..."
  if [ -f "scripts/run-linters.sh" ]; then
    bash scripts/run-linters.sh --files "$(echo "$STAGED_FILES" | paste -sd, -)"
  fi
fi
# --- end smart-code-review hook ---
HOOK_EOF
  chmod +x "$PRE_COMMIT_HOOK"
  echo "Created $PRE_COMMIT_HOOK"
fi

# 2. Pre-push hook: Branch sanity check
if [ -f "$PRE_PUSH_HOOK" ]; then
  if grep -q "smart-code-review" "$PRE_PUSH_HOOK"; then
    echo "smart-code-review hook already installed in $PRE_PUSH_HOOK"
  else
    cat >> "$PRE_PUSH_HOOK" << 'HOOK_EOF'

# --- smart-code-review hook ---
echo "[smart-code-review] Validating branch before push..."
# --- end smart-code-review hook ---
HOOK_EOF
    echo "Appended smart-code-review to existing $PRE_PUSH_HOOK"
  fi
else
  cat > "$PRE_PUSH_HOOK" << 'HOOK_EOF'
#!/usr/bin/env bash
set -e

# --- smart-code-review hook ---
echo "[smart-code-review] Validating branch before push..."
# Run tests if test runner exists
if [ -f "scripts/run-tests.sh" ]; then
  bash scripts/run-tests.sh
fi
# --- end smart-code-review hook ---
HOOK_EOF
  chmod +x "$PRE_PUSH_HOOK"
  echo "Created $PRE_PUSH_HOOK"
fi

chmod +x "$HOOKS_DIR"/*
echo " Git hooks installed successfully!"

