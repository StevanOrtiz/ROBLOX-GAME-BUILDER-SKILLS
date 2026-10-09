# Roblox Game Builder Skills

Lean skills for building Roblox games through the Studio MCP.

| Skill | Does |
|---|---|
| `ihaveadhd` | Every reply ultra-short. Expands only when asked |
| `roblox-mcp-lean` | No full-tree reads, surgical edits, one build+verify call, 2-try failure cap |
| `roblox-code-structure` | Default Luau layout, server-authoritative remotes, Config, cleanup |
| `roblox-ui-live` | UI as live named instances in StarterGui + controller. Style comes from your prompt |

## Install
```
mkdir -p ~/.claude/skills && cp -r skills/* ~/.claude/skills/
```

## Make `ihaveadhd` truly always-on
Skills load by description match, which is not a guarantee. Add to `~/.claude/CLAUDE.md`:
```
Use the ihaveadhd skill rules in every reply: shortest possible, answer first, no filler. Expand only if I ask to explain.
```
