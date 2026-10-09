---
name: roblox-router
description: Entry point for ANY Roblox game-development request (Luau, Studio, MCP, UI, effects, performance, review, publishing). Decides which of the other Roblox skills to load for the request, in what order, and which to skip; holds the user's workflow profile (genres, platforms, autonomy, MCP). Consult this FIRST whenever the user asks to build, change, fix, review, optimize, or ship something in a Roblox game, even if they don't name a skill.
---

# Roblox router

Pick the **smallest** set of skills the request needs. Each loaded skill costs tokens and pushes its own defaults; more is not better. The user's prompt always beats a skill's default (style, structure, naming). If the project already has a different structure, follow it.
Always on: `ihaveadhd` (reply format).

## Signals -> skills
| The user wants... | Load |
|---|---|
| Any Studio MCP action (read/edit the place, run Luau, playtest) | `roblox-mcp-lean` |
| New script / system / feature (shop, inventory, rounds, data, combat) | `roblox-code-structure` + `luau-language` |
| Where something goes, client<->server talk, remotes, module wiring, refactor layout | `roblox-architecture` |
| HUD, menu, shop screen, popup, buttons, lists | `roblox-ui-live` (+ `roblox-architecture` if it needs remotes) |
| Animation, particles, beams/trails, sound, camera shake/cutscene, lighting mood, hit feedback | `roblox-animation-vfx` |
| Lag, low FPS, stutter, memory growth, ping, many NPCs/projectiles, mobile perf | `roblox-optimization` |
| Typing, OOP/metatables, pcall/retry, async, odd runtime behavior | `luau-language` |
| "Review / audit / what's wrong / is this structure OK" | `roblox-code-review` (fixes pull in the skill that owns the topic) |
| "Ready to publish / release / update?" | `roblox-publish-checklist` |

Typical feature request: `roblox-mcp-lean` (how to touch Studio) -> `roblox-architecture` or `roblox-code-structure` (where/how) -> write -> one verify call -> one-line report.

## Skip rules
- Tiny edit (change a number, rename, tweak a property, answer a question): `ihaveadhd` + `roblox-mcp-lean` only.
- Don't load `roblox-optimization` before there is a symptom or a clearly hot path.
- Don't load review/publish skills unless asked.
- Don't announce which skills you loaded.

## New system in a known genre
Read only the matching section of `references/genres.md` (one genre), then follow the table above.

## Workflow profile (the user's, edit freely)
- Games: incremental simulators, simulator/tycoon, obby/parkour/maps, combat/shooter/PvP, RPG/adventure.
- Platforms: mobile, PC, console **equally**. Design for touch + mouse/keyboard + gamepad; use the mobile numbers as the performance floor.
- Autonomy: **apply directly**, report in one line. Ask only before destructive or irreversible actions (deleting scripts/instances, overwriting user content, data migrations) or when a requirement is truly ambiguous and changes the architecture.
- MCP: Roblox Studio **built-in** server (`execute_luau`, `script_read`, `multi_edit`, `script_grep`, `search_game_tree`, `inspect_instance`, `start_stop_play`, `get_console_output`, `get_studio_state`). If a tool isn't available, check what is and adapt; don't assume third-party tools.
- Workflow: Studio + MCP only, no Rojo/Wally/Knit. State lives in the place; `GAMEMAP.md` indexes it.
- Language: replies in Spanish. Code identifiers and log tags in English. In-game text: ask once per game, default to the user's current language.
