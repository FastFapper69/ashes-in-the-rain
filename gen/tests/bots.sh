G="${G:-/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64}"   # PC: G=/c/Users/super/Downloads/Godot_v4.7.2-stable_win64_console.exe gen/tests/bots.sh
# Every map and the trial maps, a headless bot each, 12 at once (a map takes ~5 s of wall time). Usage: bots.sh [chapter...]
cd "$(dirname "$0")/../.."
T="${TMPDIR:-/tmp}"
run(){ if [ "$1" = sb ]; then a="--sandbox=$2"; n="sandbox $2"; else a="--chapter=$1 --map=$2"; n="$1/$2"; fi
  timeout 300 "$G" --headless --audio-driver Dummy --fixed-fps 30 -- --test=play $a > "$T/bot_$1_$2.log" 2>&1
  r=$(grep -E "BOT CLEARED|REACHED THE LAST|BOT DIED|BOT STUCK|SCRIPT ERROR" "$T/bot_$1_$2.log" | head -2 | tr '\n' ' '); echo "$n: ${r:-NO RESULT}"; }
export -f run; export G T
# how many maps each chapter has (levels.gd)
counts=$(py -3 -c "
import re
s=open('levels.gd',encoding='utf-8').read().split('const SANDBOX')[0]
chs=re.split(r'\n\t\{\"title\": ', s)[1:]
print(' '.join(str(len(re.findall(r'\"street\": \[', c))) for c in chs))" 2>/dev/null || python3 -c "print('1 6 6 5')")
want="${*:-0 1 2 3}"
i=0; for n in $counts; do case " $want " in *" $i "*) for m in $(seq 0 $((n-1))); do echo "$i $m"; done;; esac; i=$((i+1)); done > "$T/maps.txt"
[ -z "$*" ] && printf "sb 0\nsb 1\n" >> "$T/maps.txt"
cat "$T/maps.txt" | xargs -P 12 -n 2 bash -c 'run $0 $1' | sort
