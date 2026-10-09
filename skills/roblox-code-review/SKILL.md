---
name: roblox-code-review
description: Review a Roblox game project in Studio via the MCP - one scripted scan finds misplaced scripts, deprecated APIs, unvalidated remotes, leaks, per-frame connection abuse, circular requires, oversized and duplicated code; then you read only the flagged lines, grade the project, and offer fixes. Use when the user asks to review, audit, check, grade or "see what's wrong with" their game or scripts, wants a pre-release or refactor check, or asks whether the project structure, security or performance is sound. Not for writing new features.
---

# Roblox code review (Studio + MCP)

Principle: **scan with code, read with judgment.** One `execute_luau` replaces dozens of grep/read calls. Hits are heuristics (candidates); confirm each by reading that line before reporting it.

## Workflow
1. **Scan (1 call).** Run `references/scan.lua` through `execute_luau`. It returns script counts, part count, remote count, and up to 6 `path:line` examples per category. Do not read the whole tree or every script first (see roblox-mcp-lean).
2. **Triage.** Order: remote_unvalidated > server_logic_exposed > placement > unstored_connect > multi_hot_connect > rest. Read only those lines (`script_read` on the range) and drop false positives.
3. **Architecture pass (judgment).** Read at most: the bootstrap(s), one Service, one Controller, `Config`. Use `roblox-architecture` as the yardstick.
4. **Report** (format below).
5. **Offer fixes.** Quick wins can be applied with `multi_edit` after the user agrees. Larger changes: propose, don't start.

If the scan can't read `Source` (reported as `unreadable`), fall back to `script_grep` per category and say so.
No MCP: ask for the Explorer listing and the 3-5 key scripts pasted. Review only those.

## What the scan can't see
Global variables (no parser; ask the user to check Script Analysis warnings), logic bugs, multi-line patterns, requires through variables, real unbounded growth. Say so in the report; don't claim a clean bill of health.

## Placement rules
| Script | Where |
|---|---|
| Script (server) | `ServerScriptService` |
| Server modules | `ServerScriptService` / `ServerStorage` |
| LocalScript | StarterPlayerScripts / StarterCharacterScripts / StarterGui / StarterPack |
| Shared modules | `ReplicatedStorage` |
| Client-only modules | `StarterPlayerScripts` (anything in ReplicatedStorage is readable by clients) |

- Script in `Workspace`: **organization** problem (vanishes with its model, hard to find). Its source is not sent to clients, so it's not an exposure.
- Server logic (DataStore, `OnServerEvent`, purchases) in a client-visible container: exposed to exploiters.
- Server `Script` (legacy context) in ReplicatedStorage/StarterGui/StarterPlayer, or a `LocalScript` in ServerScriptService: never runs.
- `game.Players` vs `GetService`: style/consistency, not deprecated.
- `coroutine.*` is not deprecated; flag only if a `task` function is simpler.

## Severity
| Level | Examples |
|---|---|
| Critical | Remote that changes currency/inventory/data with no validation; per-player or per-spawn unbounded leak |
| High | Client-computed damage/rewards; several heavy per-frame handlers; server logic exposed; scripts that never run |
| Medium | Deprecated `wait/spawn/delay` in hot paths; missing type checks on low-impact remotes; circular requires; polling loops |
| Low | Deprecated API in cold code; uncached services; magic numbers; missing `--!strict`/annotations; scripts > 300 lines |

Leaks: an unstored `:Connect` is only a leak if its enclosing function runs repeatedly (per join/spawn/round). Top-level and one-time connections are fine.

## Grades (deterministic)
| Grade | Rule |
|---|---|
| A | Nothing above Low |
| B | Medium only, <= 10 hits |
| C | >= 1 High, or Medium widespread (> 10) |
| D | >= 3 High, or any Critical |
| F | >= 2 Critical, or Critical security plus leaks |

Grade each area (Organization, Quality, Architecture, Security, Performance). Overall = the worst area.

## Report format (terse, per ihaveadhd)
```
GRADE: C   (Org B | Quality C | Arch B | Security D | Perf B)
Scanned: N scripts, M parts, R remotes. Not covered: globals, logic.

Top fixes
1. [Critical] path:line - what, why, one-line fix
2. ...
(up to 5)

Counts: deprecated X | unvalidated remotes X | leaks? X | circular X | duplicates X | >300 lines X
Quick wins (apply now?): ...
```
Each finding: `severity path:line - issue -> fix`. No long prose. Fix guidance: `roblox-architecture` (placement, remotes), `roblox-optimization` (leaks, hot paths), `luau-language` (deprecated APIs, types), `roblox-code-structure` (module shape).

## Fix tiers
- **Quick (< 30 min):** `wait` -> `task.wait`, cache services, parent-last, named constants, annotations, `GetService`.
- **Structural (1-3 h):** extract duplicates, move scripts to the right container, validate remotes, store/disconnect connections, split > 300-line scripts.
- **Architectural (days):** Services/Controllers + bootstrap loader, break circular requires, data layer over DataStore, state management.
Apply only Quick wins, and only after the user agrees; keep each change minimal (`multi_edit`), then re-run the scan once to confirm counts dropped.
