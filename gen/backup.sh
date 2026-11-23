#!/bin/bash
# Backup (user 23. 11.: "zálohuj vše, vždy i na ten obsidian"):
#  1. Claude's memory = pamet/ in the vault (a junction: seen and edited in Obsidian, LOCAL ONLY, gitignored - the repo
#     is public, the memory is private)
#  2. every change in the repo -> a commit pushed to GitHub (after git fetch: two chats push here)
# Runs at the end of every deploy (gen/deploy/deploy_pc.sh); alone: bash gen/backup.sh ["message"]
cd "$(dirname "$0")/.."
# (pamet/ is a junction onto Claude's memory folder since 23. 11. - "use Obsidian's memory": nothing to copy, one set of
#  files edited from both sides; recreate it if missing: powershell New-Item -ItemType Junction -Path pamet -Target <memory>)
[ -e pamet/MEMORY.md ] || echo "BACKUP NOTE: pamet/ is not linked to the memory folder (see the comment above)"
git fetch -q origin
if ! git merge-base --is-ancestor origin/main HEAD; then echo "BACKUP STOP: origin/main has commits this clone does not - merge first"; exit 1; fi
git add -A
if git diff --cached --quiet; then echo "BACKUP OK: nothing new"; else
  git commit -qm "Backup: ${1:-notes and work in progress}

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git push -q origin main && echo "BACKUP OK: pushed $(git rev-parse --short HEAD)"
fi
