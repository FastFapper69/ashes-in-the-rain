# book-to-skill in this repo

Vendored from https://github.com/virgiliojr94/book-to-skill @ e7bb659 (2026-11-03), MIT (LICENSE.md). Only the runtime parts are copied: `SKILL.md`, `scripts/extract.py`, `book_to_skill/`, `tools/validate_skill.py`, `tools/scan_generated_skill.py`. Upstream `SKILL.md` is unchanged – project rules are here.

## Project rules (override upstream defaults)
1. **Write generated skills project-local**: `BOOK_TO_SKILL_SCOPE=project`, root `.claude/skills/<slug>/`. The cloud container's `~/.agents/skills` disappears with the session.
2. **This repo is PUBLIC.** A skill made from a third-party copyrighted book (Godot books, game-design books, comics) must **not** be committed here – keep it in the session or on the user's PC, or in a private repo. Only skills from the project's own text (HANDOFF, GDD, story doc), official docs under an open licence (Godot docs are CC BY 3.0 – keep attribution), or the user's own writing may go into git.
3. Run with the isolated interpreter: `python3 -I .claude/skills/book-to-skill/scripts/extract.py <paths> --mode text|technical --install-missing no`, `BOOK_SKILL_WORKDIR=/home/claude/work/b2s` to fix the workdir.
4. After generating: `python3 .claude/skills/book-to-skill/tools/validate_skill.py <skill>/SKILL.md` and `python3 .claude/skills/book-to-skill/tools/scan_generated_skill.py <skill>` – both must pass.
5. Godot ignores dot-folders, so nothing here goes into the export.

## What it is for here
- `ashes-znalosti` (project knowledge) was built in this structure from HANDOFF.md – use Mode 4 (Update / Fold-in) to refresh it.
- Turning a book/PDF the user supplies into a private study skill (Godot, optimisation, comic art), then folding *our own conclusions* (not the book text) into `ashes-znalosti` / `ashes-vyzkum`.
