# Roblox Game Builder Skills

Lean skills for building Roblox games through the **built-in Studio MCP** (no Rojo).

| Skill | Does |
|---|---|
| `ihaveadhd` | Every reply ultra-short. Expands only when asked |
| `roblox-router` | Decides which skills a request needs; holds your workflow profile; genre playbooks |
| `roblox-mcp-lean` | No full-tree reads, `GAMEMAP.md`, surgical edits, one build+verify call, 2-try failure cap |
| `roblox-code-structure` | Default Luau layout, server-authoritative remotes, Config, cleanup |
| `roblox-architecture` | Where things go, script types, which remote to use, module wiring, anti-patterns |
| `roblox-ui-live` | UI as live named instances in StarterGui + controller. Style comes from your prompt |
| `roblox-animation-vfx` | Animator rules, FX presets (data), camera shake/cutscene, hit feedback, lighting presets |
| `roblox-optimization` | Measure-first perf rules; Scheduler, Cleaner, ObjectPool |
| `luau-language` | Luau gotchas only: strict types, classes, errors, async, deprecated APIs |
| `roblox-code-review` | One scripted scan + targeted reads, graded report |
| `roblox-publish-checklist` | Preflight scan + human checklist, GO / NO-GO, `PUBLISH.md` |

## Install
```
bash install.sh        # macOS / Linux / Git Bash
./install.ps1          # Windows PowerShell (untested)
```
It copies the skills to `~/.claude/skills`, the output style to `~/.claude/output-styles`, and adds a marked block to `~/.claude/CLAUDE.md` (re-running replaces only that block).

## Make `ihaveadhd` always on (use all three; each covers a gap)
1. **CLAUDE.md block** (installed above): loaded every session, tells Claude to follow the style and consult the router.
2. **Output style**: restart Claude Code (it reads style files at startup), then run `/output-style ihaveadhd`. That saves the choice for the current project only; to make it global put `"outputStyle": "ihaveadhd"` in `~/.claude/settings.json` (the value is case-sensitive). Built-in alternatives: `Concise` (short replies) and `Proactive` (acts without asking on routine decisions). Docs: an output style is an instruction, not a guarantee. `keep-coding-instructions` only matters on the full system prompt; if styles seem ignored, set `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0`.
3. **The skill** itself covers the details and the "expand when asked" rule.

Skills load by description match and are never 100% guaranteed; the CLAUDE.md block + output style are what make it reliable.

## Your workflow profile
Lives in `skills/roblox-router/SKILL.md` ("Workflow profile") and in `claude-md-block.md`. Edit both when your workflow changes, then run the installer again.
