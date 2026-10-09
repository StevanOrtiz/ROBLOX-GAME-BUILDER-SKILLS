# Roblox Game Builder Skills

Lean skills for building Roblox games through the Studio MCP.

| Skill | Does |
|---|---|
| `ihaveadhd` | Every reply ultra-short. Expands only when asked |
| `roblox-mcp-lean` | No full-tree reads, surgical edits, one build+verify call, 2-try failure cap |
| `roblox-code-structure` | Default Luau layout, server-authoritative remotes, Config, cleanup |
| `roblox-ui-live` | UI as live named instances in StarterGui + controller. Style comes from your prompt |
| `roblox-optimization` | Measure-first perf rules: per-frame, memory, network, mobile. Includes Scheduler, Cleaner, ObjectPool |
| `roblox-architecture` | Where things go, script types, which remote to use, module wiring, anti-patterns. Studio+MCP, no Rojo |
| `roblox-animation-vfx` | Animator rules, FX presets (data not code), camera shake/cutscene, hit feedback, lighting presets, sound |
| `luau-language` | Luau gotchas only: strict types, classes that type-check, errors, async, deprecated->replacement |
| `roblox-code-review` | One scripted scan via execute_luau + targeted reads, deterministic grading, terse report |

## Install
```
mkdir -p ~/.claude/skills && cp -r skills/* ~/.claude/skills/
```

## Make `ihaveadhd` truly always-on
Skills load by description match, which is not a guarantee. Add to `~/.claude/CLAUDE.md`:
```
Use the ihaveadhd skill rules in every reply: shortest possible, answer first, no filler. Expand only if I ask to explain.
```
