cd "$(dirname "$0")/../.."   # the repo root
G="${G:-/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64}"   # PC: G=/c/Users/super/Downloads/Godot_v4.7.2-stable_win64_console.exe
# a window for the screenshots: a virtual one in a cloud container, the real one on the PC
shown(){ if command -v xvfb-run >/dev/null; then timeout 400 xvfb-run -a -s "-screen 0 1600x800x24" "$G" --rendering-driver opengl3 "$@"; else timeout 400 "$G" "$@"; fi; }
for cm in "1 2" "2 4" "3 1" "1 1"; do set -- $cm; rm -rf /tmp/tops_$1_$2; mkdir -p /tmp/tops_$1_$2; rm -f _shots/tops_*
shown --resolution 780x360 --fixed-fps 30 -- --test=tops --chapter=$1 --map=$2 2>&1 | grep -E "^tops" > /tmp/tops_$1_$2/log.txt
cp _shots/tops_* /tmp/tops_$1_$2/ 2>/dev/null; done
echo DONE > /tmp/tops_done
