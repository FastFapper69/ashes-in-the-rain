"""Run the game for a test and never let it hang (user 17. 11.: "when it does nothing for a few seconds, kill it -
don't make us wait five minutes"). Prints the game's output; kills the whole process tree (the window too) when it
prints nothing for IDLE seconds or runs longer than MAX. `timeout` in Git Bash does not kill the windowed Godot.

usage: py -3 gen/tests/rungd.py [--idle 20] [--max 180] -- <godot args...>
       (the Godot binary: $G, else the PC's console build)
Exit code: the game's, or 124 when it was killed.
"""
import os, subprocess, sys, threading, time

args = sys.argv[1:]
idle, mx = 20.0, 180.0
while args and args[0] != "--":
    if args[0] == "--idle":
        idle = float(args[1]); args = args[2:]
    elif args[0] == "--max":
        mx = float(args[1]); args = args[2:]
    else:
        break
if args and args[0] == "--":
    args = args[1:]
G = os.environ.get("G", os.path.join(os.path.expanduser("~"), "Downloads", "Godot_v4.7.2-stable_win64_console.exe"))
p = subprocess.Popen([G] + args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
last = [time.time()]
def pump():
    for line in p.stdout:
        last[0] = time.time()
        sys.stdout.write(line)
        sys.stdout.flush()
threading.Thread(target=pump, daemon=True).start()
t0 = time.time()
while p.poll() is None:
    time.sleep(0.5)
    now = time.time()
    if now - last[0] > idle or now - t0 > mx:
        why = "silent %.0f s" % (now - last[0]) if now - last[0] > idle else "over %.0f s" % mx
        print("RUNGD: killed (%s)" % why, flush=True)
        if os.name == "nt":
            subprocess.run(["taskkill", "/PID", str(p.pid), "/T", "/F"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            p.kill()
        sys.exit(124)
sys.exit(p.returncode)
