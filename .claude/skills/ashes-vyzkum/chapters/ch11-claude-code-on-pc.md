# Chapter 11: Working from Claude Code on the PC

## Core Idea
Development moved to Claude Code on the user's Windows PC (claude.ai chat still used sometimes). Locally Claude can run the real Godot editor and game, so the "look at it yourself" rule can be closed by tools instead of by the user's phone.

## Tools worth adding (ask the user before installing anything)
- **Godot MCP servers** (MCP = tools Claude Code can call):
  - `Coding-Solo/godot-mcp` (MIT, free, `claude mcp add godot -- npx @coding-solo/godot-mcp`): launch editor, run project, capture debug output; no screenshots or input.
  - `Erodenn/godot-mcp-runtime` (MIT, free): injects a temporary autoload bridge while running → screenshots, simulated input, read the scene tree, run a script in the live game; removes itself afterwards. Best fit for "check every scene yourself".
  - Paid editor add-ons exist (Godot MCP Pro, GDAI MCP, Ziva) – not needed.
  - Our own `--test=` modes already do headless screenshots; the MCP adds live, interactive checks on the real PC GPU.
- **Unit tests**: GdUnit4 (MIT, Godot 4, scene runner with simulated input, headless, GitHub Action) or GUT. Good for pure logic (XP curve, score multipliers, CURVE table, pack lists, barks no-repeat) – not a replacement for the screenshot tests. [H] start with 10–20 tests on `instincts.gd`, `barks.gd`, scoring.
- **Hooks** (`.claude/settings.json`): deterministic commands Claude Code runs at fixed moments. Candidates:
  - PostToolUse on Edit/Write of `*.gd` → `godot --headless --check-only` style parse check (fast, catches syntax errors at once).
  - Stop → quick smoke test (one `--test=` mode) so a turn cannot end with a broken build.
  - Keep heavy runs (bot over all maps) manual – hooks have timeouts and run with full user permissions.
- **TokenEconomizer** (microsoft, Apache 2.0): learns repo facts across Claude Code sessions, prunes unused tools, guards failure loops; claims 18–31 % lower cost on SWE-Bench. Makes sense now that sessions run locally on the PC (state lives in `~/.tokeneconomizer`). Overlaps with our CLAUDE.md + ashes-znalosti; [H] try for a week, compare usage.

## Rules that stay
- CLAUDE.md + skills in `.claude/skills/` are read by Claude Code automatically – keep them current (fold-in rule).
- Two places push to `main` (PC Claude Code and cloud chats): fetch/merge before every commit, same as before.
- Secrets (Supabase keys, API keys) never in the public repo; on the PC keep them in env vars or `.claude/settings.local.json` (not committed).

## Key Takeaways
1. A runtime Godot MCP gives Claude eyes and hands on the real game.
2. Hooks turn "remember to test" into "always tested".
3. Unit tests for numbers, screenshot tests for looks.
