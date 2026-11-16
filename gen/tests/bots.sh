G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
cd /home/claude/repo
run(){ timeout 400 $G --headless --fixed-fps 30 -- --test=play --chapter=$1 --map=$2 > /tmp/bot_$1_$2.log 2>&1; r=$(grep -E "BOT CLEARED|REACHED THE LAST|BOT DIED|BOT STUCK|SCRIPT ERROR" /tmp/bot_$1_$2.log | head -2 | tr '\n' ' '); echo "$1/$2: $r"; }
export -f run; export G
for c in 1 2 3; do for m in 0 1 2 3 4 5; do echo "$c $m"; done; done > /tmp/maps.txt
echo "0 0" >> /tmp/maps.txt
cat /tmp/maps.txt | xargs -P 6 -n 2 bash -c 'run $0 $1'
