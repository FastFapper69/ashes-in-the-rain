#!/bin/bash
# PC deploy (Git Bash): gen/deploy/deploy_pc.sh "commit message"
# One repo on the PC: sources -> main from this clone, web build -> gh-pages from a separate clone ../ink-and-lead-pages.
# Override paths with G=<godot.exe> PY=<python> PAGES=<dir> if they move.
set -e
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
G="${G:-/c/Users/super/Downloads/Godot_v4.7.2-stable_win64_console.exe}"
PY="${PY:-py -3}"
PAGES="${PAGES:-$REPO/../ink-and-lead-pages}"
export PYTHONUTF8=1
[ -x "$G" ] || { echo "STOP: Godot not found at $G (set G=...)"; exit 1; }
[ -d "$PAGES/.git" ] || git clone -q --depth 1 --single-branch -b gh-pages https://github.com/FastFapper69/ink-and-lead.git "$PAGES"
git -C "$PAGES" config user.name Claude; git -C "$PAGES" config user.email noreply@anthropic.com   # (a fresh clone has no identity: the build commit failed silently)
# Another chat may deploy to the same repo: never push over work that is not in this clone.
for d in "$REPO" "$PAGES"; do
  cd "$d" && git fetch -q origin
  b=$(git rev-parse --abbrev-ref HEAD)
  if ! git merge-base --is-ancestor "origin/$b" HEAD; then
    echo "STOP: origin/$b in $d has commits this clone does not (another chat deployed). Merge them first:"
    git log --oneline HEAD..origin/$b | head -20
    exit 1
  fi
done
cd "$REPO"
"$G" --headless --import >/dev/null 2>&1 || true
$PY gen/packs.py
# the build the player sees on the title (whatsnew.gd): the number of the commit this deploy makes, and when
printf '# Written by gen/deploy/deploy_pc.sh at every deploy: do not edit by hand.
extends RefCounted

const BUILD := %d
const DATE := "%s"
' "$(( $(git rev-list --count HEAD) + 1 ))" "$(date '+%-d %b %Y %H:%M' | tr a-z A-Z)" > version.gen.gd
mkdir -p build && rm -f build/pack_*.pck
"$G" --headless --export-release Web build/index.html 2>&1 | grep -i error || true
for p in $(grep -o 'name="pack_[a-z]*"' export_presets.cfg | cut -d'"' -f2); do
  "$G" --headless --export-pack "$p" build/$p.pck 2>&1 | grep -i error || true
  echo "$p $(( $(stat -c %s build/$p.pck) / 1048576 )) MB"
done
echo "pck $(( $(stat -c %s build/index.pck) / 1048576 )) MB"
git add -A
git diff --cached --quiet || git commit -qm "$1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -q origin main
$PY gen/deploy/version_build.py "$REPO/build" "$PAGES"
GHP_BEFORE=$(git -C "$PAGES" rev-parse HEAD)
cd "$PAGES" && git add -A && git commit -qm "Deploy: $1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git push -q origin gh-pages
git fetch -q origin && [ "$(git rev-parse HEAD)" != "$GHP_BEFORE" ] && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/gh-pages)" ] && echo GHP-OK || echo "GHP-FAILED: no new build commit on gh-pages"
cd "$REPO" && git fetch -q origin && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] && echo MAIN-OK
grep -o '"executable":"ashes-[0-9a-f]*"' "$PAGES/index.html"
