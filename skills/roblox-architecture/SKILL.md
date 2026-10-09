---
name: roblox-architecture
description: Decision reference for how a Roblox game is organized when built live in Studio through the MCP (no Rojo) - which service/container each script, module, remote, asset and UI goes in, which script type to use, which communication primitive (RemoteEvent, RemoteFunction, BindableEvent, UnreliableRemoteEvent) fits, how to wire modules without circular requires, and how to fix structural anti-patterns. Use when starting a new game's structure, when the user asks "where should this go", "how should client and server talk", "how do I organize modules", when adding a new system that touches several containers, or when refactoring a messy place (god scripts, scripts in Workspace, circular requires, polling loops).
---

# Roblox architecture (Studio + MCP, no Rojo)

Default: one bootstrap script per side + Service/Controller ModuleScripts. No framework (Knit is third-party, needs a package manager, and its official repository is archived: no more updates). Existing project structure wins; match it.
Naming matches `roblox-code-structure`: `Shared/`, `Services/`, `Controllers/`, `Remotes/`.

## 1. Where things go
| Thing | Container | Why |
|---|---|---|
| Server logic (Services), bootstrap `Main` | `ServerScriptService` | Clients never receive it |
| Server-only assets (maps, NPC templates, loot) | `ServerStorage` | Hidden; clone into Workspace on demand |
| Shared modules (Config, Types, Util), Remotes, assets both sides need | `ReplicatedStorage` | Replicated to every client. Everything here is readable by exploiters |
| Loading screen only | `ReplicatedFirst` | Runs before the rest loads. Keep tiny |
| Persistent UI | `StarterGui/<Feature>Gui` (see roblox-ui-live) | Cloned into each PlayerGui |
| Client bootstrap + Controllers | `StarterPlayer/StarterPlayerScripts` | Cloned once per join; survives respawn |
| Per-life behavior (footsteps, anim) | `StarterCharacterScripts` | Recloned each spawn, gone on death |
| Default tools | `StarterPack` | Cloned into Backpack. Tool-embedded Script runs server, LocalScript client |
| World + runtime entities | `Workspace` | Parts, models, terrain. **No scripts here** |

Server-only logic in `ReplicatedStorage` is readable by exploiters. Keep validation and secrets server-side.

## 2. Script type
| Type | Runs | Put in |
|---|---|---|
| `Script` | Server (`RunContext = Legacy/Server`) | `ServerScriptService` |
| `LocalScript` | Client | StarterPlayerScripts / CharacterScripts / StarterGui / StarterPack |
| `ModuleScript` | Side of the requirer, once per side (cached) | Where its visibility should match: server-only -> `ServerScriptService`; shared -> `ReplicatedStorage/Shared`; client-only -> StarterPlayerScripts |

A `Script` with `RunContext = Client` also runs client-side, from containers like `ReplicatedStorage`. Prefer plain `LocalScript` unless you need that.
Scripts/LocalScripts are thin bootstraps. Logic lives in ModuleScripts.

## 3. Replication (what each side sees)
- Server -> clients: Workspace, ReplicatedStorage, ReplicatedFirst, Lighting, SoundService.
- Never sent to clients: ServerScriptService, ServerStorage.
- Server-created/changed instances in replicated containers reach everyone. Client-created ones stay local.
- Client changes replicate only for physics of parts the client owns (its character); property edits don't.

## 4. Communication
| Need | Use |
|---|---|
| Action/notification, no reply | `RemoteEvent` |
| Client asks, server answers | `RemoteFunction` + `InvokeServer` only |
| Server asks client a question | Two `RemoteEvent`s (request/response). **Never `InvokeClient`**: client error or leave hangs the server thread |
| Same side, decoupled | `BindableEvent` (or a direct service call) |
| High-frequency, loss OK (cosmetic) | `UnreliableRemoteEvent`, throttled 10-20 Hz, small payload |

Rules:
- Client sends **intent** ("attack target X"), never outcome ("dealt 500").
- First lines of every `OnServerEvent`/`OnServerInvoke`: `typeof` checks, existence, range, ownership, per-player cooldown. Template: `references/communication.md`.
- Reserve `RemoteFunction` for real data requests. Fire-and-forget uses `RemoteEvent`.
- All remotes live in `ReplicatedStorage/Remotes`, named `VerbNoun`. Create them **once** as persistent instances via `execute_luau` (idempotent find-or-create) and list them in `GAMEMAP.md`. Not recreated at runtime by random scripts.

## 5. Modules
- Contract: `Init()` (own state only, no cross-service calls) then `Start()` (connect events, call others). Bootstrap runs all Init, then all Start: `references/loader.lua`.
- Circular require A<->B. Fix in this order:
  1. Extract the shared part into module C that both require.
  2. Event-decouple (BindableEvent / signal).
  3. Pass the dependency in `Init` instead of requiring at load.
- One module, one job. Over ~300 lines or two unrelated responsibilities -> split.
- Talk to other modules through their public functions, never their `_private` fields.
- Class-style modules: `Foo.new`, methods with typed `self`, `export type`. Example: `references/patterns.md`.

## 6. Building with the MCP
- No create-script tool: create the ModuleScript/Script in `execute_luau` (`Instance.new`, set `Name`, `Parent`, `Source`), then change it only with `multi_edit`.
- Set instance names and parents deliberately; the name is the path other code requires.
- After adding a Service/Controller: confirm the bootstrap loads it (folder scan does this automatically), update `GAMEMAP.md`.
- Keep reads narrow (see `roblox-mcp-lean`).

## 7. Anti-patterns -> fix
| Problem | Fix |
|---|---|
| God script (500+ lines) | Thin bootstrap + Service modules |
| Scripts in Workspace (server source isn't sent to clients, but they vanish with their model and are hard to find) | Move to `ServerScriptService`; find models by path or CollectionService tag |
| Server logic in ReplicatedStorage | Move to ServerScriptService/ServerStorage |
| Trusting client values | Server recalculates from its own data |
| Polling `while true do wait()` | Events: `.Died`, `.Changed`, `GetPropertyChangedSignal`, remotes |
| Duplicated logic across scripts | One ModuleScript in the right container |
| `RemoteFunction` for everything | `RemoteEvent` unless a reply is needed |
| `wait/spawn/delay` | `task.wait/spawn/delay/defer` |
| Remotes created ad hoc in many scripts | One `Remotes` folder, created once |

## 8. Scale
- Jam / <10 scripts: flat is fine (a few Scripts + `Config`). Still keep remotes in one folder and validate.
- Anything that will grow: Services/Controllers + bootstrap from day one. Retrofitting costs more tokens than starting right.
