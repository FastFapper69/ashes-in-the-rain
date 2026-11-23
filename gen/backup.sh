#!/bin/bash
# Backup (user 23. 11.: "zálohuj vše, vždy i na ten obsidian"):
#  1. Claude's memory (outside the repo) -> pamet/ in the vault: seen in Obsidian, LOCAL ONLY (gitignored - the repo is
#     public, the memory is private)
#  2. every change in the repo -> a commit pushed to GitHub (after git fetch: two chats push here)
# Runs at the end of every deploy (gen/deploy/deploy_pc.sh); alone: bash gen/backup.sh ["message"]
cd "$(dirname "$0")/.."
MEM="${MEM:-/c/Users/super/.claude/projects/C--Users-super/memory}"
mkdir -p pamet
[ -d "$MEM" ] && cp -u "$MEM"/*.md pamet/ 2>/dev/null
for f in pamet/*.md; do [ -f "$MEM/$(basename "$f")" ] || rm -f "$f"; done
git fetch -q origin
if ! git merge-base --is-ancestor origin/main HEAD; then echo "BACKUP STOP: origin/main has commits this clone does not - merge first"; exit 1; fi
git add -A
if git diff --cached --quiet; then echo "BACKUP OK: nothing new"; else
  git commit -qm "Backup: ${1:-notes and work in progress}

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git push -q origin main && echo "BACKUP OK: pushed $(git rev-parse --short HEAD)"
fi
