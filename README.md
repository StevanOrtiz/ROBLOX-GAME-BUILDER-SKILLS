# Roblox Game Builder Skills

Lean Claude Code skills for building Roblox games through the **built-in Studio MCP** (no Rojo). Goals: fewer tokens, fewer MCP round trips, consistent structure, and ultra-short replies.

## Skills

| Skill | Does |
|---|---|
| `ihaveadhd` | Every reply ultra-short; expands only when asked |
| `roblox-router` | Picks which skills a request needs; holds your workflow profile; genre playbooks |
| `roblox-mcp-lean` | No full-tree reads, `GAMEMAP.md`, surgical edits, one build+verify call, failure cap |
| `roblox-code-structure` | Default Luau layout, server-authoritative remotes, Config, cleanup |
| `roblox-architecture` | Where things go, script types, which remote to use, module wiring, anti-patterns |
| `roblox-ui-live` | UI as live named instances in StarterGui + controller; style comes from your prompt |
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

It copies skills to `~/.claude/skills`, the output style to `~/.claude/output-styles`, adds a marked block to `~/.claude/CLAUDE.md` (re-running replaces only that block), and sets `"outputStyle": "ihaveadhd"` in `~/.claude/settings.json` only if no style is set yet. Restart Claude Code afterwards.

## Make `ihaveadhd` always on

Use all three; each covers a gap.

1. **CLAUDE.md block** (installed above): loaded every session; tells Claude to follow the style and consult the router.
2. **Output style**: after restart, `/output-style ihaveadhd` (saved per project) or the global `outputStyle` key (value is case-sensitive). Built-in alternatives: `Concise`, `Proactive`. An output style is an instruction, not a guarantee; if it seems ignored, check `claude --debug` and `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0` (needed for `keep-coding-instructions`).
3. **The skill** itself covers details and the "expand when asked" rule.

Skills load by description match and are never 100% guaranteed; the CLAUDE.md block and output style are what make the style reliable.

## How skills get chosen

`roblox-router` maps a request to the smallest set of skills (e.g. new feature -> `roblox-mcp-lean` + `roblox-code-structure` + `luau-language`; HUD -> `roblox-ui-live`; lag -> `roblox-optimization`; "review" -> `roblox-code-review`; "ready to publish?" -> `roblox-publish-checklist`). Tiny edits load almost nothing. Your prompt always beats a skill default, and an existing project structure beats the default structure.

## Workflow profile (confirmed)

- Games: incremental simulators, simulator/tycoon, obby/parkour/maps, combat/PvP, RPG.
- Platforms: mobile, PC, console equally; the mobile numbers are the performance floor.
- Autonomy: apply directly, report in one line; ask only before destructive or irreversible actions.
- MCP: Roblox Studio built-in server. Studio + MCP only; no Rojo, Wally or Knit.
- Language: replies in Spanish; code, comments, logs and in-game text in English.
- Testing: only when you ask for a playtest; otherwise verify statically and report "not playtested".
- Conventions: `Shared/Services/Controllers/Remotes`, `Init/Start`, PascalCase public functions, `--!strict`, `[Tag]` logs, `GAMEMAP.md`.

The profile lives in `skills/roblox-router/SKILL.md` and `claude-md-block.md`. Edit both, then run the installer again.

## Scanners (run through `execute_luau`)

- `roblox-code-review/references/scan.lua`: placement, deprecated APIs, unvalidated remotes, leaks, circular requires, duplicates.
- `roblox-publish-checklist/references/preflight.lua`: data safety, monetization handlers, backdoors/secrets, streaming, UI sizing.

Run them with `datamodel_type = Edit`. Their hits are heuristics: confirm each by reading the cited line. The analyzer logic was tested locally with mock scripts, not inside Studio.

## Checked against official docs

- Built-in Studio MCP tool names and `execute_luau` `datamodel_type` (Edit / Client / Server).
- `UnreliableRemoteEvent`: payloads over 1,000 bytes may be dropped; delivery and order not guaranteed.
- `StreamingMinRadius` / `StreamingTargetRadius` are Not Scriptable.
- `AnalyticsService` method names; DataStore request limits; Knit's repository is archived.
- Claude Code output style format and settings key.

## Still assumptions (change if they don't fit)

- Stop and report after 2 failed fix attempts on the same problem.
- Rule-of-thumb budgets: particle rates, texture sizes, 44 px touch targets, tick rates (1-20 Hz).
- `Script.Source` is readable from `execute_luau` (docs only say "PluginOrOpenCloud"); scanners report unreadable scripts.
- Built-in particle texture paths (`rbxasset://textures/particles/*.dds`) and `ScreenGui.ScreenInsets` enum values were not verified.
- Not tested in a live Studio session.

## Layout

```
skills/<name>/SKILL.md      each skill (+ references/ loaded only when needed)
output-styles/ihaveadhd.md  output style
claude-md-block.md          always-on block (copied into CLAUDE.md)
CLAUDE.md                   same block, applies to sessions in this repo
install.sh / install.ps1    installers
```
