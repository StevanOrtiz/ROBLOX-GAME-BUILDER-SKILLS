---
name: roblox-mcp-lean
description: Rules for using the Roblox Studio MCP (search_game_tree, inspect_instance, execute_luau, script_read, script_grep, multi_edit, start_stop_play, get_console_output, screen_capture) with minimum tokens and minimum trial-and-error. Use whenever you are about to call any Roblox Studio MCP tool, edit scripts or instances in an open place, debug a Roblox game through Studio, or the user mentions MCP, Studio, the game tree, or playtesting. Never dump the whole game tree; read narrowly, change surgically, verify once.
---

# Roblox Studio MCP - lean

Goal: fewest calls, smallest reads, no guess loops. Change only what was asked.

## 1. Never read the whole tree
- Never `search_game_tree` / `inspect_instance` on game root, Workspace, or a whole service "to get oriented".
- Scope every read: narrowest path, name or class filter, shallowest depth the tool allows.
- Need a location? Read `GAMEMAP.md` first (below). Still unknown? One filtered search, not a crawl.

## 2. Keep `GAMEMAP.md` (project root, <= 60 lines)
One line per thing that matters: `Path | Class | role`. Scripts, ScreenGuis, Remotes, Config.
Format (one line each):
```
ServerScriptService.Main | Script | server bootstrap
ServerScriptService.Services.ShopService | ModuleScript | buy/sell, validates BuyItem
ReplicatedStorage.Remotes.BuyItem | RemoteEvent | client intent -> ShopService
StarterGui.ShopGui | ScreenGui | shop UI (controller: Controllers.ShopController)
```
- Read it instead of the tree. Update it in the same turn you create/rename/delete something.
- It may be stale: before relying on a path, verify that ONE path inside the build/edit call (`FindFirstChild` chain), not by re-reading the tree.
- No file system for the place? Keep the map in the chat's first reply as the compact source and refresh the changed lines only.

## 3. Read scripts narrowly, edit surgically
- Locate with `script_grep` / `script_search`, then `script_read` only the script you will change.
- Edit with `multi_edit` on the smallest span. Never rewrite a whole script to change one function.
- A successful `multi_edit` is proof the text changed. Don't read it back.
- Keep the file's existing style and structure. Add, don't reorganize.

## 4. One `execute_luau` = build + verify + compact result
- Make scripts idempotent: find-or-create by name, set properties, so a retry is harmless.
- End the same script with its own assertions and `return` a short summary (counts, missing names, created paths). Never return dumps of instances.
- Wrap in `pcall`; on failure return `err` text, not silence.
- Don't yield inside `execute_luau` (`task.wait`, `WaitForChild` w/o timeout, `PreloadAsync`): a community pack reported that output is lost when a script yields (not stated in the official docs). Split the call or use `task.delay` and return.
- `execute_luau` takes a `datamodel_type`: `Edit` (the open place: builds, scans, property changes), `Server` or `Client` (the running game during Play). Use `Edit` for building; `Server`/`Client` to inspect live state. For logs over time, have game code print tagged lines and read `get_console_output`.
- Batch independent MCP calls in one turn.

## 5. Test budget
- Think and check statically first (names, paths, types) before touching Studio.
- Playtest once at the end of a feature, not after each edit.
- `get_console_output` once, and design prints with a tag (`[Shop] ...`) so you read only your lines.
- `screen_capture` only if the question is visual. Max 1 per task.
- `get_studio_state` before play-only tools. Don't assume mode.

## 6. Failure policy
- Error -> read it -> fix the root cause. Max 2 attempts per problem, each different and reasoned.
- Still failing -> stop. Report in 1-2 lines: error + what you tried + your best hypothesis. No third blind retry.
- "Target is not reachable" / no Studio found -> `list_roblox_studios` once, then tell the user to re-toggle Studio's MCP server. Don't loop. Often a Studio-version issue, not your code.

## 7. Autonomy and report
- Apply requested changes directly. Ask only before destructive or irreversible actions (deleting scripts/instances, overwriting user content, data migrations) or when an ambiguity changes the architecture.
- Report per `ihaveadhd`: `Done: <what>`, paths changed, nothing else.

## 8. Built-in Studio MCP quirks
- The "Enable Studio as MCP server" toggle can turn itself off after a Studio update. Check it first when nothing connects.
- Connections can drop every few minutes. One `list_roblox_studios` / `get_studio_state`, then ask the user to re-toggle; don't loop.
- Play-mode tools returning "Target is not reachable" right after an update are usually a Studio regression, not your code.
- Only one MCP server connected at a time.
