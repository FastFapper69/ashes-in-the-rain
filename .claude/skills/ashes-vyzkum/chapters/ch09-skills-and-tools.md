# Chapter 9: Anthropic skills – what helps this project

## Core Idea
`github.com/anthropics/skills` (@e4bb5d9, 2026-11-16) holds 19 example skills plus the Agent Skills spec (agentskills.io). Most of them are built into claude.ai already; a few teach methods we should copy. Our own skills (ashes-znalosti, ashes-vyzkum, ui-papir) pass its `skill-creator/scripts/quick_validate.py`.

## Verdict per skill
| Skill | Use for Ashes | How |
|---|---|---|
| **webapp-testing** | YES – check the web build before/after deploy | vendored in `.claude/skills/webapp-testing` (Apache 2.0); recipe in its PROJECT.md |
| **skill-creator** | YES – keep our skills sharp | built in (`anthropic-skills:skill-creator`); quick_validate after edits; description evals when a skill fails to trigger |
| **frontend-design** | PARTLY – UI method, not its look | built in; take: plan tokens first, one bold element per screen, self-critique from screenshots, copy rules. Our ui-papir brief wins where they differ (caps captions are our style) |
| **doc-coauthoring** | YES for story/GDD – "reader testing" | read from GitHub when needed (no licence file → not vendored). A fresh reader without our context answers questions about the story doc → finds plot holes and contradictions. Needs sub-agents: only when the user asks for them |
| **canvas-design** | METHOD only | write a short "visual philosophy" before a batch of Gemini briefs so every drawing shares one direction; never use its code-drawn output as game art (user rule) |
| **slack-gif-creator** | SMALL | its `core/gif_builder.py` + validators can turn `_shots` frames into short GIFs (show a change on the phone, store/social clips) |
| **mcp-builder** | LATER | a local MCP on the PC (Godot run + screenshot, Gemini download) would replace slow computer-use steps; only if the user wants it |
| **xlsx / pptx / pdf / docx** | WHEN ASKED | built in: balance tables (CURVE, XP, guns) as a sheet for the user; a pitch deck for publishers |
| **discernment-nudge** | WORKFLOW | after big recommendations, 2–3 concrete "check this" questions – at most once per chat |
| claude-api | NO | the game uses no LLM at runtime |
| algorithmic-art | NO | procedural art is rejected by the user |
| theme-factory, brand-guidelines, internal-comms, academy-guide, web-artifacts-builder | NO (for now) | web-artifacts-builder only if we ever build a level/balance viewer page |

## Lessons for writing our skills (skill-creator + spec)
- Three loading levels: name+description always (~100 words), SKILL.md when triggered (< 500 lines), references only on demand – our index + chapters already follow it.
- The **description decides triggering**: write *when* to use it, with concrete user-like phrasings; test with 8–10 should-trigger and 8–10 tricky near-miss queries.
- Imperative instructions, explain *why* (models follow reasons better than capital-letter MUSTs).
- Scripts are black boxes: run `--help` first, do not read them into context unless needed.
- Long reference files (> 300 lines) get a table of contents.

## Key Takeaways
1. Use webapp-testing for every web deploy check.
2. Use reader testing on the story doc before a chapter's story is locked.
3. Re-validate skills after edits; fix descriptions when a skill is missed.
