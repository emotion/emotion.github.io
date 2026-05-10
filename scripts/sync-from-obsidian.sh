#!/usr/bin/env bash
# Sync blog source files from Obsidian vault to Quartz content directory.
#
# Source: Obsidian vault Default/Blog/ directory (the single source of truth)
# Target: Quartz content/ directory (auto-generated, safe to be overwritten)
#
# Usage: ./scripts/sync-from-obsidian.sh

set -euo pipefail

OBSIDIAN_BLOG="/Users/emotion/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN/Default/Blog"
QUARTZ_CONTENT="$(cd "$(dirname "$0")/.." && pwd)/content"

if [ ! -d "$OBSIDIAN_BLOG" ]; then
  echo "error: Obsidian Blog directory not found: $OBSIDIAN_BLOG" >&2
  exit 1
fi

mkdir -p "$QUARTZ_CONTENT"

# Preserve content/index.md (home page) if it exists, because index.md is NOT
# sourced from Obsidian — it's an authoring-time file in the Quartz repo.
TMP_INDEX=""
if [ -f "$QUARTZ_CONTENT/index.md" ]; then
  TMP_INDEX="$(mktemp)"
  cp "$QUARTZ_CONTENT/index.md" "$TMP_INDEX"
fi

rsync -av --delete \
  --exclude='.backup/' \
  --exclude='.trash/' \
  --exclude='.obsidian/' \
  --exclude='.workbuddy/' \
  --exclude='.DS_Store' \
  --include='*/' \
  --include='*.md' \
  --include='*.png' \
  --include='*.jpg' \
  --include='*.jpeg' \
  --include='*.gif' \
  --include='*.svg' \
  --exclude='*' \
  "$OBSIDIAN_BLOG/" "$QUARTZ_CONTENT/"

# Restore index.md
if [ -n "$TMP_INDEX" ]; then
  mv "$TMP_INDEX" "$QUARTZ_CONTENT/index.md"
fi

echo ""
echo "Sync complete. Files in content/:"
ls -1 "$QUARTZ_CONTENT"
