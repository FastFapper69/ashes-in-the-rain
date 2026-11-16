G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
cd /home/claude/repo
run(){ cfg="$1"; c=$2; m=$3; r=$(timeout 400 $G --headless --fixed-fps 30 -- --test=play --chapter=$c --map=$m $cfg 2>&1 | grep -E "BOT CLEARED|TIMEOUT" | head -1); echo "$cfg|$c/$m|$r"; }
export -f run; export G
for cfg in "--side=revolver" "--side=revolver --two --perks=twoguns" "--side=beretta" "--side=beretta --two --perks=b_two"; do for cm in "1 1" "1 3" "2 1" "2 3" "3 1" "3 3"; do echo "$cfg;$cm"; done; done | xargs -P 8 -d '\n' -n 1 bash -c 'IFS=";" read cfg cm <<< "$0"; set -- $cm; run "$cfg" $1 $2'
