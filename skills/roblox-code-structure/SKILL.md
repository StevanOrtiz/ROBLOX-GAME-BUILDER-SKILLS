---
name: roblox-code-structure
description: Standard structure and conventions for Roblox Luau game code - where scripts live, one-bootstrap-per-side, services and controllers as ModuleScripts, server-authoritative remotes with validation, Config module for tunables, naming, strict typing, connection cleanup, DataStore safety. Use whenever the user asks you to write, add, refactor, or review any Roblox script, system, or gameplay feature (shop, inventory, combat, rounds, data saving, remotes), or asks where code should go. Follow the existing project's structure if it already has one; this skill is the default when there is none.
---

# Roblox code structure

Existing project structure wins. Match it. Below is the default for new work.

## Layout (no loose scripts; full placement + communication rules in roblox-architecture)
```
ReplicatedStorage
  Shared/         Config, Types, Util   (pure, no side effects)
  Remotes/        RemoteEvents/Functions, named VerbNoun
ServerScriptService
  Main            ONE Script: requires + Init/Start every Service
  Services/       <Domain>Service  (Data, Shop, Combat, Round...)
StarterPlayer/StarterPlayerScripts
  Main            ONE LocalScript: requires + starts every Controller
  Controllers/    <Domain>Controller (UI, Input, Camera...)
StarterGui/<Feature>Gui   live UI (see roblox-ui-live)
```
New feature = new Service and/or Controller module + Remotes + Config entries. Not a new loose Script.

## Module shape
```lua
--!strict
-- <one line: purpose>
local Config = require(game.ReplicatedStorage.Shared.Config)
local Svc = {}

function Svc.Init() end   -- create state, no cross-service calls
function Svc.Start() end  -- connect events, call other services

return Svc
```
Main calls all `Init`, then all `Start`. Services never `require` each other at load time circularly; pass dependencies in `Init` or require lazily.

## Rules
- **Server authoritative.** Client sends *intent*, server validates type, range, ownership, cooldown, then acts. Never trust client numbers (prices, damage, positions).
- **Config.** Every tunable in `Shared/Config`. No magic numbers in logic.
- **Pure logic** (math, rules, formatting) in its own module with no Roblox side effects, so it is reusable and testable.
- **Remotes:** handler params typed `unknown` and checked with `typeof` (see luau-language). Named `VerbNoun` (`BuyItem`, `UpdateCoins`). Prefer RemoteEvent. Never `InvokeClient`. One handler per remote, validates first line.
- **State flow:** server owns state -> pushes to client (remote/attribute) -> controller renders. UI never owns truth.
- **Naming:** modules, classes, types, instances and module public functions (`Init`, `Start`, `Register`) PascalCase; locals, params, local functions camelCase; private fields `_name`; constants UPPER_SNAKE inside Config. More Luau rules in luau-language.
- **Luau:** `--!strict`, type public function signatures, `task.wait/spawn/delay` (not `wait`), `:GetService`, events over polling loops.
- **Cleanup:** store connections/threads and release them on player leave or teardown (`Shared/Util/Cleaner`, see roblox-optimization). No leaks per-spawn.
- **Errors:** no bare `pcall(f)`. `local ok, err = pcall(f); if not ok then warn("[Tag] "..tostring(err)) end`. Tag every log line `[Feature]`.
- **DataStore:** load once on join into a session cache; mutate cache; save on leave, `BindToClose`, and autosave; use `UpdateAsync`; retry with backoff; never block gameplay on a save.
- **Client waits:** `WaitForChild` with a timeout, only on the client, only for things you didn't create.
- **Size:** module > ~300 lines -> split by responsibility.
- **Comments:** header line + the non-obvious "why". No narration.

## Changing existing code
Smallest diff that does the job. Don't rename, reformat, or restructure what wasn't asked. If a refactor is needed, say so in one line and ask.

## Before saying done
Check: new remote has server validation? tunables in Config? connections cleaned? tags on logs? module registered in Main?
