#!/bin/bash
# usage: gen/deploy/deploy.sh (copy to /home/claude/deploy.sh in a new container) "commit message"   (repo -> ink-and-lead main, build -> gh-pages)
set -e
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
cd /home/claude/repo
$G --headless --import >/dev/null 2>&1 || true
python3 gen/packs.py
rm -f build/pack_*.pck
$G --headless --export-release Web build/index.html 2>&1 | grep -i error | grep -v ALSA || true
for p in $(grep -o 'name="pack_[a-z]*"' export_presets.cfg | cut -d'"' -f2); do $G --headless --export-pack "$p" build/$p.pck 2>&1 | grep -i error | grep -v ALSA || true; echo "$p $(( $(stat -c %s build/$p.pck) / 1048576 )) MB"; done
echo "pck $(( $(stat -c %s build/index.pck) / 1048576 )) MB"
cd /home/claude/ink-and-lead
git ls-files | while read f; do case "$f" in HANDOFF.md|.gitignore) continue;; esac; [ -e "/home/claude/repo/$f" ] || git rm -q "$f"; done
cd /home/claude/repo && tar --exclude=./build --exclude=./.godot --exclude=./_shots --exclude=./.git --exclude=./.gitignore -cf - . | (cd /home/claude/ink-and-lead && tar xf -)
cd /home/claude/ink-and-lead && git add -A && git commit -qm "$1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01C3g9eatrmPMSywcp5HyC7Q" && git push -q origin main 2>&1 | grep -v 'warning\|GH001\|remote:' || true
python3 /home/claude/repo/gen/deploy/version_build.py /home/claude/repo/build /tmp/ghp && cd /tmp/ghp && git add -A && git commit -qm "Deploy: $1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01C3g9eatrmPMSywcp5HyC7Q" && git push -q origin gh-pages 2>&1 | grep -v 'warning\|GH001\|remote:' || true
git fetch -q origin && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/gh-pages)" ] && echo GHP-OK
cd /home/claude/ink-and-lead && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] && echo MAIN-OK
rm -rf /mnt/user-data/outputs/godot2 && mkdir -p /mnt/user-data/outputs/godot2 && cd /home/claude/repo && tar --exclude=./build --exclude=./.godot --exclude=./.git -cf - . | (cd /mnt/user-data/outputs/godot2 && tar xf -)
