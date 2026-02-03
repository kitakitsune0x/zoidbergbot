#!/bin/bash
# Sync with upstream openclaw/zoidbergbot
# Usage: ./scripts/sync-upstream.sh

set -e

echo "Fetching upstream..."
git fetch upstream

echo ""
echo "New commits from upstream:"
git log --oneline main..upstream/main | head -20

echo ""
read -p "Merge upstream/main? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Merging upstream/main..."
git merge upstream/main --no-edit || {
    echo ""
    echo "Merge conflicts detected. Resolve them, then run:"
    echo "  bun scripts/rebrand.ts"
    echo "  git add -A && git commit"
    exit 1
}

echo ""
echo "Running rebrand script on new code..."
bun scripts/rebrand.ts

echo ""
echo "Verifying TypeScript..."
pnpm exec tsc --noEmit

echo ""
echo "Done! Run 'pnpm lint' to check for any issues."
