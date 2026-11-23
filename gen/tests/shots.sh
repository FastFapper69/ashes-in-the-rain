#!/bin/bash
# Pictures of one test and a contact sheet of them to look at in one go (rule: every visual change is looked at).
# usage: gen/tests/shots.sh "<test args>" [WxH] [pattern]
#   gen/tests/shots.sh "--test=look:6300@0,9750@0 --sandbox=2"            -> _shots/look_*.png -> _shots/sheet.png
#   gen/tests/shots.sh "--test=doorkick --sandbox=2" 1560x720 "door_0[7-9]|door_1[0-5]"
cd "$(dirname "$0")/../.."
res="${2:-1560x720}"
name=$(echo "$1" | sed -E 's/.*--test=([a-z]+).*/\1/')
[ "$name" = look ] && pat="look_" || pat="${3:-}"
rm -f _shots/sheet.png _shots/${name}_*.png
py -3 gen/tests/rungd.py --idle 40 --max 120 -- --path . --position -3000,-3000 --resolution "$res" --fixed-fps 30 -- $1 2>&1 | grep -E "^shot|SCRIPT ERROR|UI BAD" | cut -c1-90
py -3 gen/tests/sheet.py "${3:-$pat}"
