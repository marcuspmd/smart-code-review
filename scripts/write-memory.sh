#!/usr/bin/env bash
# Append or manage entries in the review memory file.
# Delegates to manage-memory.sh for robust additions, replacements, deletions, and compaction.
#
# Usage:
#   bash write-memory.sh --section "Recurring Issues" --entry "Reports prone to N+1 queries"
#   bash write-memory.sh --remove "old rule text"
#   bash write-memory.sh --replace "old rule text" --with "new rule text"
#   bash write-memory.sh --compact

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec /bin/bash "$SCRIPT_DIR/manage-memory.sh" "$@"
