#!/usr/bin/env bash
# Discover installed peer skills and print their paths for the agent to read.
# The agent reads each discovered SKILL.md for lens enrichment — it does NOT invoke them.
# Usage: bash discover-skills.sh [--extra-paths <path1,path2,...>]
#
# Compatible with POSIX / Bash 3.2+ (macOS default) and Bash 4+.
#
# Discovery order:
#   1. Project-level skills: .agents/skills, .agent/skills, .skills
#   2. Global installs:
#      ~/.claude/skills, ~/.gemini/config/skills, ~/.config/skills, ~/.cursor/skills
#   3. Paths from --extra-paths (from tools.extra_skills in config)

ROOT="${PWD}"
EXTRA_PATHS=""

# Names to exclude — self and any known aliases/mirrors
SELF_NAMES=("smart-code-review" "code-review-agent")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extra-paths|-e) EXTRA_PATHS="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

FOUND=0
# Delimited string for deduplication (compatible with Bash 3.2 on macOS)
SEEN_DIRS=":"

is_self() {
  local name="$1"
  for self in "${SELF_NAMES[@]}"; do
    [ "$name" = "$self" ] && return 0
  done
  return 1
}

is_seen() {
  local dir="$1"
  [[ "$SEEN_DIRS" == *":$dir:"* ]]
}

mark_seen() {
  local dir="$1"
  SEEN_DIRS="${SEEN_DIRS}${dir}:"
}

emit_skill() {
  local skill_dir="$1"
  local skill_file="$2"
  local label="${3:-}"
  local skill_name
  skill_name=$(basename "$skill_dir")
  is_self "$skill_name" && return
  
  # Deduplicate by directory path
  if is_seen "$skill_dir"; then
    return
  fi
  mark_seen "$skill_dir"

  [ -n "$label" ] && echo "# skill: $skill_name ($label)" || echo "# skill: $skill_name"
  echo "# path:  $skill_file"
  FOUND=1
}

discover_in_dir() {
  local base_dir="$1"
  local filename="$2"
  local expanded_dir="${base_dir/#\~/$HOME}"
  [ -d "$expanded_dir" ] || return
  for skill_dir in "$expanded_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_file="${skill_dir}${filename}"
    [ -f "$skill_file" ] || continue
    # Prefer SKILL.md over skill.md — resolve to canonical name for dedup
    canonical_check="${skill_dir}SKILL.md"
    [ -f "$canonical_check" ] && skill_file="$canonical_check"
    emit_skill "$skill_dir" "$skill_file"
  done
}

# 1. Project-level skills
for p_dir in "$ROOT/.agents/skills" "$ROOT/.agent/skills" "$ROOT/.skills"; do
  discover_in_dir "$p_dir" "SKILL.md"
  discover_in_dir "$p_dir" "skill.md"
done

# 2. Global installs — check each directory once, prefer SKILL.md over skill.md
GLOBAL_SKILL_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.gemini/config/skills"
  "$HOME/.config/skills"
  "$HOME/.cursor/skills"
)

for g_dir in "${GLOBAL_SKILL_DIRS[@]}"; do
  [ -d "$g_dir" ] || continue
  for skill_dir in "$g_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    if [ -f "${skill_dir}SKILL.md" ]; then
      emit_skill "$skill_dir" "${skill_dir}SKILL.md"
    elif [ -f "${skill_dir}skill.md" ]; then
      emit_skill "$skill_dir" "${skill_dir}skill.md"
    fi
  done
done

# 3. Explicit extra paths from tools.extra_skills in config
if [ -n "$EXTRA_PATHS" ]; then
  IFS=',' read -ra PATHS <<< "$EXTRA_PATHS"
  for p in "${PATHS[@]}"; do
    p="${p/#\~/$HOME}"
    p=$(echo "$p" | xargs)
    [ -f "$p" ] || continue
    skill_dir=$(dirname "$p")/
    emit_skill "$skill_dir" "$p" "extra"
  done
fi

if [ "$FOUND" -eq 0 ]; then
  echo "# no peer skills discovered"
fi
