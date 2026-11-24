#!/bin/bash
# --test=moves: every move of the figure (Eddie: grey prologue) in runs of 28 frames -> _shots/mv_NN_<move>.png; sheet: py -3 gen/tests/mvsheet.py FROM TO out.png [top]
cd "$(dirname "$0")/../.."
rm -f _shots/mv_*.png
for f in 0 28 56 84; do
py -3 gen/tests/rungd.py --idle 40 --max 150 -- --path . --position -3000,-3000 --resolution 1560x720 --fixed-fps 30 -- --test=moves --sandbox=3 --mvfrom=$f 2>&1 | grep -E "SCRIPT ERROR" | head -3
done
ls _shots/mv_*.png | wc -l
