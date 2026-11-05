#!/usr/bin/env bash
# Interactive and automated initialization of smart-code-review configuration, memory, and rules.
# Creates .ai/review.yml, .ai/review-memory.md, and optional .ai/review-rules.md.
#
# Usage:
#   bash init.sh                # Interactive mode (asks questions with smart defaults)
#   bash init.sh --defaults     # Non-interactive mode with standard defaults
#   bash init.sh --global       # Create global config in ~/.ai/review.yml
#   bash init.sh --with-hooks   # Also initialize git / workflow hooks

set -euo pipefail

ROOT="${PWD}"
INTERACTIVE=1
IS_GLOBAL=0
WITH_HOOKS=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --defaults|-d|--non-interactive|-y) INTERACTIVE=0; shift ;;
    --global|-g) IS_GLOBAL=1; shift ;;
    --with-hooks) WITH_HOOKS=1; shift ;;
    --force|-f) FORCE=1; shift ;;
    *) shift ;;
  esac
done

if [ "$IS_GLOBAL" -eq 1 ]; then
  TARGET_DIR="$HOME/.ai"
  CONFIG_FILE="$TARGET_DIR/review.yml"
  MEMORY_FILE=""
  RULES_FILE=""
else
  TARGET_DIR="$ROOT/.ai"
  CONFIG_FILE="$TARGET_DIR/review.yml"
  MEMORY_FILE="$TARGET_DIR/review-memory.md"
  RULES_FILE="$TARGET_DIR/review-rules.md"
fi

echo "=================================================="
echo "    smart-code-review: Project Initialization     "
echo "=================================================="
echo "Target directory: $TARGET_DIR"
echo ""

# Auto-detect project context and tools
DETECTED_STACKS=()
[ -f "$ROOT/composer.json" ]                                     && DETECTED_STACKS+=("PHP / Laravel")
[ -f "$ROOT/package.json" ]                                      && DETECTED_STACKS+=("TypeScript / JavaScript")
[ -f "$ROOT/Cargo.toml" ]                                        && DETECTED_STACKS+=("Rust")
[ -f "$ROOT/go.mod" ]                                            && DETECTED_STACKS+=("Go")
[ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/requirements.txt" ] && DETECTED_STACKS+=("Python")
[ -f "$ROOT/Dockerfile" ] || [ -f "$ROOT/docker-compose.yml" ]   && DETECTED_STACKS+=("Docker")
[ -d "$ROOT/migrations" ] || [ -d "$ROOT/database/migrations" ]  && DETECTED_STACKS+=("SQL Migrations")

if [ "${#DETECTED_STACKS[@]}" -gt 0 ]; then
  echo "Detected project stack: ${DETECTED_STACKS[*]}"
else
  echo "Project stack: Generic / Multi-language"
fi
echo ""

# Default values
LANG_CHOICE="pt-BR"
AUTO_UPDATE="false"
ENABLE_SONAR="false"

# Interactive wizard if terminal attached and interactive mode enabled
if [ "$INTERACTIVE" -eq 1 ] && [ -t 0 ]; then
  # 1. Language
  echo "1. Review Report Language:"
  echo "   [1] pt-BR (Portuguese - Brazil) [default]"
  echo "   [2] en (English)"
  echo "   [3] es (Spanish)"
  read -r -p "Select language (1-3) [1]: " lang_input || true
  case "${lang_input:-1}" in
    2) LANG_CHOICE="en" ;;
    3) LANG_CHOICE="es" ;;
    *) LANG_CHOICE="pt-BR" ;;
  esac

  # 2. SonarQube / SonarCloud Integration
  echo ""
  read -r -p "Enable SonarQube / SonarCloud integration template? (y/n) [n]: " sonar_input || true
  case "${sonar_input:-n}" in
    [yY]*) ENABLE_SONAR="true" ;;
    *) ENABLE_SONAR="false" ;;
  esac

  # 3. Memory Auto-update
  echo ""
  read -r -p "Automatically propose memory additions for recurring patterns? (y/n) [y]: " mem_input || true
  case "${mem_input:-y}" in
    [nN]*) AUTO_UPDATE="false" ;;
    *) AUTO_UPDATE="true" ;;
  esac

  # 4. Git Hooks
  if [ "$IS_GLOBAL" -eq 0 ]; then
    echo ""
    read -r -p "Install Git pre-commit and pre-push review hooks? (y/n) [n]: " hook_input || true
    case "${hook_input:-n}" in
      [yY]*) WITH_HOOKS=1 ;;
      *) WITH_HOOKS=0 ;;
    esac
  fi
  echo ""
fi

mkdir -p "$TARGET_DIR"

# Write Config File
if [ -f "$CONFIG_FILE" ] && [ "$FORCE" -eq 0 ]; then
  echo "Configuration file already exists: $CONFIG_FILE (skipping, use --force to overwrite)"
else
  cat > "$CONFIG_FILE" << EOF
# .ai/review.yml
# Configuration for smart-code-review

language: "$LANG_CHOICE"

# Review priorities
priorities:
  - "Security vulnerabilities and auth leaks"
  - "Data loss, table locks, and backward-incompatible migrations"
  - "Concurrency bugs, race conditions, and error swallowing"
  - "Unbounded queries and memory leaks"
  - "Architecture, DDD layer boundaries, and coupling"

always_check:
  - security
  - data
  - correctness
  - performance
  - architecture
  - tests
  - ops

# Ignore patterns
ignore:
  paths:
    - "**/*.min.js"
    - "**/*.min.css"
    - "**/vendor/**"
    - "**/node_modules/**"
    - "**/dist/**"
    - "**/build/**"

# Persistent Memory Settings
memory:
  file: ".ai/review-memory.md"
  auto_update: $AUTO_UPDATE

rules_file: ".ai/review-rules.md"

# Workflow Lifecycle Hooks (optional)
hooks:
  pre_review: ""
  post_review: ""
  on_blocker: ""
  on_approved: ""

# Standardized Tools Configuration
tools:
  test:
    commands:
      run: "bash scripts/run-tests.sh"
    parameters:
      diff_scoped: true
      timeout: 120

  lint:
    commands:
      run: "bash scripts/run-linters.sh"
    parameters:
      diff_scoped: true
EOF

  if [ "$ENABLE_SONAR" = "true" ]; then
    cat >> "$CONFIG_FILE" << 'EOF'

  sonar:
    commands:
      health: "curl -sf http://localhost:9000/api/system/status"
      run: "sonar-scanner"
    parameters:
      diff_scoped: true
      min_coverage: 80
EOF
  fi

  echo "Created configuration: $CONFIG_FILE"
fi

# Write Memory File (if project-level)
if [ -n "$MEMORY_FILE" ]; then
  if [ -f "$MEMORY_FILE" ] && [ "$FORCE" -eq 0 ]; then
    echo "Memory file already exists: $MEMORY_FILE (preserving)"
  else
    cat > "$MEMORY_FILE" << 'EOF'
# Review Memory

## Architecture

## Recurring Issues

## Accepted Patterns

## False Positives

## Custom Rules
EOF
    echo "Created memory file: $MEMORY_FILE"
  fi
fi

# Write Rules File (if project-level)
if [ -n "$RULES_FILE" ]; then
  if [ -f "$RULES_FILE" ] && [ "$FORCE" -eq 0 ]; then
    echo "Rules file already exists: $RULES_FILE (preserving)"
  else
    cat > "$RULES_FILE" << 'EOF'
# Project-Specific Code Review Rules

# Add team conventions and architectural constraints here.
# The reviewer evaluates all PRs against these rules.

1. **No Raw SQL Without Parameter Binding**: Always use parameterized queries or ORM query builders.
2. **Layering Integrity**: Controllers should only interact with Services/UseCases; never query repositories or DB directly.
3. **Graceful Error Handling**: Do not swallow exceptions in catch blocks without logging with context.
EOF
    echo "Created rules template: $RULES_FILE"
  fi
fi

# Install hooks if requested
if [ "$WITH_HOOKS" -eq 1 ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/install-hooks.sh" ]; then
  bash "$(dirname "${BASH_SOURCE[0]}")/install-hooks.sh"
fi

echo ""
echo " smart-code-review setup complete!"
echo "   Config: $CONFIG_FILE"
[ -n "$MEMORY_FILE" ] && echo "   Memory: $MEMORY_FILE"
[ -n "$RULES_FILE" ]  && echo "   Rules:  $RULES_FILE"
echo ""
echo "Try running: review my changes"

