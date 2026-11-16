#!/bin/bash
# usage: shoot.sh chapter map xs tag
cd /home/claude/repo
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
D=$(mktemp -d)
cp -r . $D/r 2>/dev/null
