# Chapter 2: Tests

## Core Idea
Everything is tested by rendering real frames headless and by a bot that clears maps. Pictures land in `_shots/`; a test is done only after looking at them zoomed.

## Command
`xvfb-run -a -s "-screen 0 1700x800x24" godot --rendering-driver opengl3 --resolution 1560x720 --fixed-fps 30 -- --test=<mode> [flags]`
Repeat UI-relevant shots at 1280 wide too.

## Modes (`--test=`)
- **Play/bot**: `play --chapter=N --map=M`, `hops` (map after map, texture MB), `curve` (`--step=N`), `endcut`, `probe` (frees node kinds, prints what each held), `erase`.
- **Menus/UI**: `menu --progress=N`, `pause`, `page`, `card`, `choice`, `paperkit`, `instincts --leads=N --pin=… --detail=…`, `gunsmith --gun=X --pick=N [--buy]`, `tally --chapter=1 --map=1`, `levelup`.
- **Cutscenes**: `cut:<id>` (eddie, interlude, teague, dream, kessler, underground, briggs, docks, memory), `voice:<cut id>` (logs each line with timing).
- **Look/framing**: `look:x [--high] [--inner] [--smoke]`, `tops`, `rooms` (every street drawing), `bulbs:x`, `pin:i`, `give`, `fall:x[,player]`.
- **Mechanics**: `men:hook|dynamite|sniper|shield|load`, `kick`, `ricochet`, `rope:climb|zip|swing`, `pipe`, `disarm`, `hat`, `bag`, `coatdive`, `jumpseq`, `fxsheet`, `aicover --chapter=2 --map=1`.
- **Map FX**: `el`, `fog`, `oncoming`, `sheets`, `neondrop`, `storm`, `rock`, `sea`, `steam`, `rats`, `freight`, `flood`, `girder`.
- **Flags**: `--guilt=N`, `--perks=all|id,id`, `--xp=N`, `--instincts=all`, `--figscale=`, `--lift=`, `--cones` (rejected look, comparison only), `--texdump`, `--timing`, `--log-sound`, `--packs=<dir>` with `--main-pack build/index.pck` (split-build test).

## Rules
- Output must contain **no `UI BAD`** (Paper.audit runs inside every `_shot`).
- After movement/scale/AI changes: bot over **all** maps (18 at last count).
- Look test stops on a diary page x (reading pauses the game) → pick another x.

## Key Takeaways
1. A green log is not enough – open the shots, zoom 2–3×.
2. New mechanic → add a `--test=` mode that frames it, like every mechanic above.
3. Split-build test (packs) before shipping anything that changes what is in which pack.
