#!/bin/bash
# One map's bot, its result line, and on a timeout what was left and where it got stuck (the bot scope rule: only the
# maps a change can reach - all of them through bots.sh only for shared code, once before a deploy).
# usage: gen/tests/bot.sh sb 2      |  gen/tests/bot.sh 1 3      (chapter, map)      [N runs at once: RUNS=3]
cd "$(dirname "$0")/../.."
G="${G:-/c/Users/super/Downloads/Godot_v4.7.2-stable_win64_console.exe}"
T="${TMPDIR:-${TEMP:-/tmp}}"
if [ "$1" = sb ]; then a="--sandbox=$2"; else a="--chapter=$1 --map=$2"; fi
for i in $(seq 1 "${RUNS:-1}"); do
  ( log="$T/bot_${1}_${2}_$i.log"
    timeout 300 "$G" --headless --audio-driver Dummy --fixed-fps 30 -- --test=play $a > "$log" 2>&1
    r=$(grep -E "BOT CLEARED|REACHED THE LAST|BOT DIED|BOT TIMEOUT|SCRIPT ERROR" "$log" | head -2 | tr '\n' ' ')
    echo "run $i: ${r:-NO RESULT}"
    if ! echo "$r" | grep -q "CLEARED\|LAST STAND"; then grep -E "left:|SCRIPT ERROR" "$log" | head -6; grep "BOT t " "$log" | tail -3 | cut -c1-110; fi ) &
done
wait
