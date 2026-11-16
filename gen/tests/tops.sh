cd /home/claude/repo
for cm in "1 2" "2 4" "3 1" "1 1"; do set -- $cm; rm -rf /tmp/tops_$1_$2; mkdir -p /tmp/tops_$1_$2; rm -f _shots/tops_*
timeout 400 xvfb-run -a -s "-screen 0 1000x600x24" /home/claude/godot/Godot_v4.7.2-stable_linux.x86_64 --rendering-driver opengl3 --resolution 780x360 --fixed-fps 30 -- --test=tops --chapter=$1 --map=$2 2>&1 | grep -E "^tops" > /tmp/tops_$1_$2/log.txt
cp _shots/tops_* /tmp/tops_$1_$2/ 2>/dev/null; done
echo DONE > /tmp/tops_done
