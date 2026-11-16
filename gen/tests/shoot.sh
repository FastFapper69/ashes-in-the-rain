#!/bin/bash
# usage: shoot.sh chapter map xs tag
cd "$(dirname "$0")/../.."
G="${G:-/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64}"   # PC: G=/c/Users/super/Downloads/Godot_v4.7.2-stable_win64_console.exe
D=$(mktemp -d)
cp -r . $D/r 2>/dev/null
