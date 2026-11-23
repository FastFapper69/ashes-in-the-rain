#!/bin/bash
# New drawings into the game in one go: Godot imports them (writes the .import files), gen/basis_imports.py sets
# Basis / caps and big_sizes.gd, Godot imports again with those settings. (One pass alone failed: basis_imports needs
# the .import files to exist - 23. 11.)
cd "$(dirname "$0")/.."
G="${G:-/c/Users/super/Downloads/Godot_v4.7.2-stable_win64_console.exe}"
"$G" --headless --path . --import 2>&1 | grep -iE "^ERROR|SCRIPT ERROR" | head -5
py -3 gen/basis_imports.py 2>&1 | tail -1
"$G" --headless --path . --import 2>&1 | grep -iE "^ERROR|SCRIPT ERROR" | head -5
echo "import done"
