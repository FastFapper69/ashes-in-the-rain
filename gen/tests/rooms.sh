cd /home/claude/repo
mkdir -p /tmp/rooms
for spec in "laundry 1 2 7480" "warehouse 1 2 14680" "tenement 1 3 3050" "club 1 4 7370" "hold 2 2 11260" "office 2 4 8750" "cityhall 3 1 11170" "catacombs 3 4 5100"; do
 set -- $spec; rm -f _shots/look_*
 timeout 120 xvfb-run -a -s "-screen 0 1600x800x24" /home/claude/godot/Godot_v4.7.2-stable_linux.x86_64 --rendering-driver opengl3 --resolution 1560x720 --fixed-fps 30 -- --test=look:$4 --chapter=$2 --map=$3 2>&1 | grep SCRIPT
 cp _shots/look_0.png /tmp/rooms/$1.png
done
echo DONE > /tmp/rooms/done
