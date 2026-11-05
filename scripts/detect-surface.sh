#!/usr/bin/env bash
# Detect and report the review surface for the current repository.
# Prints the detected mode, stats, and the exact git diff command to run.
#
# Usage:
#   bash detect-surface.sh                        # auto: staged → unstaged → untracked → branch ahead → last commit
#   bash detect-surface.sh --branch develop       # diff current branch vs develop
#   bash detect-surface.sh --branch main          # diff current branch vs main
#   bash detect-surface.sh --commits 3            # last 3 commits
#   bash detect-surface.sh --staged               # staged changes only
#   bash detect-surface.sh --pr                   # PR mode: branch vs auto-detected base (main/master/develop)

set -euo pipefail

MODE=""
TARGET_BRANCH=""
COMMITS=""

# Common lockfiles and generated files to ignore from raw diffs to protect context window
LOCKFILE_EXCLUDES="':!*.lock' ':!package-lock.json' ':!pnpm-lock.yaml' ':!yarn.lock' ':!composer.lock'"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch|-b)  TARGET_BRANCH="$2"; MODE="branch";  shift 2 ;;
    --commits|-c) COMMITS="${2:-3}";  MODE="commits"; shift 2 ;;
    --staged|-s)  MODE="staged";  shift ;;
    --pr|-p)      MODE="pr";      shift ;;
    *)            shift ;;
  esac
done

[ -z "$MODE" ] && MODE="auto"

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "HEAD")

# Find the default base branch (main > master > develop)
# Returns local branch or remote origin/branch if local doesn't exist
find_base() {
  for b in main master develop; do
    if git show-ref --verify --quiet "refs/heads/$b" 2>/dev/null; then
      echo "$b"
      return
    fi
    if git show-ref --verify --quiet "refs/remotes/origin/$b" 2>/dev/null; then
      echo "origin/$b"
      return
    fi
  done
  echo "main"
}

print_branch_surface() {
  local base="$1" label="$2"
  local stats files commits_ahead
  stats=$(git diff "$base"...HEAD --shortstat 2>/dev/null || echo "could not compute stats")
  files=$(git diff "$base"...HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
  commits_ahead=$(git log "$base"..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
  echo "# surface: $label"
  echo "# branch:  $CURRENT_BRANCH → $base"
  echo "# commits: $commits_ahead ahead of $base"
  echo "# files:   $files changed"
  echo "# stats:   $stats"
  echo "# command: git diff $base...HEAD -- . $LOCKFILE_EXCLUDES"
  echo ""
  echo "# commits on this branch:"
  git log "$base"..HEAD --oneline 2>/dev/null | head -20
}

case "$MODE" in

  staged)
    staged_files=$(git diff --staged --name-only 2>/dev/null || true)
    if [ -z "$staged_files" ]; then
      echo "# surface: staged"
      echo "# status:  no staged changes"
      echo "# hint:    run 'git add <files>' to stage changes for review"
      exit 0
    fi
    count=$(echo "$staged_files" | wc -l | tr -d ' ')
    stats=$(git diff --staged --shortstat 2>/dev/null)
    echo "# surface: staged changes"
    echo "# files:   $count changed"
    echo "# stats:   $stats"
    echo "# command: git diff --staged -- . $LOCKFILE_EXCLUDES"
    ;;

  branch)
    # Check if specified branch exists locally or as origin/
    RESOLVED_BRANCH="$TARGET_BRANCH"
    if ! git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH" 2>/dev/null; then
      if git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH" 2>/dev/null; then
        RESOLVED_BRANCH="origin/$TARGET_BRANCH"
      fi
    fi
    print_branch_surface "$RESOLVED_BRANCH" "branch diff ($CURRENT_BRANCH → $RESOLVED_BRANCH)"
    ;;

  commits)
    n="${COMMITS:-3}"
    stats=$(git diff "HEAD~$n"..HEAD --shortstat 2>/dev/null || echo "could not compute stats")
    files=$(git diff "HEAD~$n"..HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
    echo "# surface: last $n commits"
    echo "# branch:  $CURRENT_BRANCH"
    echo "# files:   $files changed"
    echo "# stats:   $stats"
    echo "# command: git diff HEAD~$n..HEAD -- . $LOCKFILE_EXCLUDES"
    echo ""
    echo "# commits included:"
    git log "HEAD~$n"..HEAD --oneline 2>/dev/null
    ;;

  pr)
    base=$(find_base)
    print_branch_surface "$base" "PR mode ($CURRENT_BRANCH → $base)"
    ;;

  auto)
    staged=$(git diff --staged --name-only 2>/dev/null || true)
    unstaged=$(git diff --name-only 2>/dev/null || true)
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null || true)
    base=$(find_base)
    ahead=$(git log "$base"..HEAD --oneline 2>/dev/null || true)

    staged_count=0
    [ -n "$staged" ] && staged_count=$(echo "$staged" | wc -l | tr -d ' ')
    unstaged_count=0
    [ -n "$unstaged" ] && unstaged_count=$(echo "$unstaged" | wc -l | tr -d ' ')
    untracked_count=0
    [ -n "$untracked" ] && untracked_count=$(echo "$untracked" | wc -l | tr -d ' ')

    if [ "$staged_count" -gt 0 ]; then
      stats=$(git diff --staged --shortstat 2>/dev/null)
      echo "# surface: auto → staged changes"
      echo "# files:   $staged_count changed"
      echo "# stats:   $stats"
      if [ "$unstaged_count" -gt 0 ] || [ "$untracked_count" -gt 0 ]; then
        echo "# notice:  $unstaged_count unstaged and $untracked_count untracked file(s) also present in working tree"
        echo "# hint:    run 'git add <files>' to include them, or pass --branch/--commits to review broader scope"
      fi
      echo "# command: git diff --staged -- . $LOCKFILE_EXCLUDES"

    elif [ "$unstaged_count" -gt 0 ]; then
      stats=$(git diff --shortstat 2>/dev/null)
      echo "# surface: auto → unstaged (working tree) changes"
      echo "# files:   $unstaged_count changed"
      echo "# stats:   $stats"
      if [ "$untracked_count" -gt 0 ]; then
        echo "# notice:  $untracked_count untracked file(s) also present in working tree"
        echo "# hint:    run 'git add <files>' to track and include new files"
      fi
      echo "# command: git diff -- . $LOCKFILE_EXCLUDES"

    elif [ "$untracked_count" -gt 0 ]; then
      echo "# surface: auto → untracked new files only"
      echo "# files:   $untracked_count untracked file(s)"
      echo "# list:    $(echo "$untracked" | head -10 | tr '\n' ' ')"
      echo "# hint:    stage files with 'git add <files>' for a full review diff"
      echo "# command: git status --short"

    elif [ -n "$ahead" ]; then
      print_branch_surface "$base" "auto → branch ahead of $base"

    else
      stats=$(git diff HEAD~1..HEAD --shortstat 2>/dev/null || echo "no previous commit")
      files=$(git diff HEAD~1..HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
      echo "# surface: auto → last commit (no staged/unstaged/untracked/ahead changes)"
      echo "# files:   $files changed"
      echo "# stats:   $stats"
      echo "# command: git diff HEAD~1..HEAD -- . $LOCKFILE_EXCLUDES"
      echo ""
      echo "# commit:"
      git log -1 --oneline 2>/dev/null
    fi
    ;;
esac
