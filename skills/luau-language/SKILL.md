---
name: luau-language
description: Luau gotchas and house style for writing or reviewing Roblox code - strict typing rules, OOP that type-checks, error handling and retries, async with the task library, sharp edges (nil in tables, the # operator, truthiness, shallow clones, closures), string-pattern limits, and deprecated APIs with their replacements. Use whenever you write, review, or debug Luau where types, classes/metatables, pcall, yielding, table behavior or odd runtime behavior matter, or when a script uses wait/spawn/delay, global variables, or loosely typed remote handlers. Skips language basics on purpose; the model already knows them.
---

# Luau - only the non-obvious

Don't explain syntax or restate basics in answers. Apply the rules below.

## Features to use (Luau, not Lua 5.1)
`+= -= *= /= //= ..=`, `continue`, generalized `for k, v in t do` (no `pairs/ipairs`), interpolation `` `{x}` ``, if-expressions `local v = if c then a else b`, `signal:Once(fn)`, `table.clone/freeze/clear/create/find`, `math.clamp/round/sign`, `string.split`, `task.*`, `buffer`.

## Types
- `--!strict` on every new module. Annotate every public function (params + return). Avoid `any`; when unavoidable keep it local.
- **Remote/untrusted args are `unknown`, not `string`/`number`.** A typed param is a lie the client controls; check with `typeof` then use.
- `x :: T` hides nil. Prefer `local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end`.
- `FindFirstChild` returns `Instance?`; narrow with `:IsA()` or `assert(x, msg)`.
- Export shared types with `export type` from a ModuleScript, require it for annotations.
- `T?` == `T | nil`. Records for data, string-literal unions for enums (`"Common" | "Rare"`).

## Classes
- In strict mode, fields must be in the constructor literal: `setmetatable({ a = a, b = b }, C)`. Creating `{}` then `self.a = ...` fails type-checking.
- Method with explicit typed `self` (`function C.Do(self: C)`), call with `:`.
- Don't forget `C.__index = C`.
- Prefer **composition over inheritance**: metatable chains lose type info and force `:: any`. Template: `references/idioms.lua`.
- Instance state on `self`, never on the class table (shared by all instances).

## Errors
- Wrap only fallible calls: DataStore, HTTP, MarketplaceService, `require` of untrusted. Not everything.
- `local ok, result = pcall(fn, args...)`. Never bare `pcall(f)` and drop the error; `warn("[Tag] "..tostring(result))`.
- `xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end)` for traces.
- Retry with exponential backoff, capped attempts: `references/idioms.lua`.
- Fail closed on the server (reject), fail inert on cosmetics.

## Async
- `task.spawn` runs now until first yield; `task.defer` runs at end of the current cycle; `task.delay(t, fn)`; `task.cancel(thread)` to stop pending ones; `task.wait` returns elapsed.
- A yield inside an event handler only suspends that handler's thread. Don't rely on handler order.
- Promise libraries need a package manager. With the Studio+MCP workflow use `task` + `pcall`; add Promise only if the user already has it.
- `execute_luau` (MCP) drops all output if the script yields (see roblox-mcp-lean).
- `WaitForChild` without a timeout can hang forever and logs "Infinite yield". Use a timeout, only for instances you did not create.

## Sharp edges
- Arrays are 1-based; `t[0]` is nil, no error.
- `#t` is reliable only for contiguous arrays. Never set `t[i] = nil` mid-array; use `table.remove`.
- Assigning `nil` deletes the key; can't store nil. Need "checked, absent"? Use a sentinel: `local NONE = table.freeze({})`.
- Only `nil` and `false` are falsy. `0`, `""`, `{}` are truthy.
- Tables are references. `table.clone` is shallow; nested tables stay shared. Deep copy must guard cycles (idioms file).
- `for` loops give a fresh variable per iteration (closures safe). `while` loops share the outer variable: copy it to a `local` before capturing.
- Method call `obj.Method()` vs `obj:Method()` mismatch is the usual "attempt to index nil" cause.
- Instances: after `:Destroy()` the Lua variable still points at it. Check `inst.Parent` or use `Destroying`.
- `table.concat` needs strings/numbers: `tostring` booleans and others first.
- `#` on strings counts bytes, not characters. Use `utf8.len` for text.
- Time: `os.clock()` for durations, `os.time()` / `DateTime.now()` for wall time. `tick()` is deprecated.
- `math.random` is auto-seeded in Roblox. Use `Random.new()` only for reproducible or independent streams.

## String patterns are not regex
No alternation (`|`), no `{n}` counts, no groups-with-quantifiers. `-` is lazy `*`. Escape magic chars `( ) . % + - * ? [ ] ^ $` with `%`. Searching literal text: `string.find(s, text, 1, true)` (plain) instead of escaping.

## Deprecated -> use
| Deprecated | Use |
|---|---|
| `wait()`, `spawn()`, `delay()` | `task.wait/spawn/delay` |
| `Instance.new(class, parent)` | create, set properties, set `Parent` last |
| `game.Players` etc. | `game:GetService("Players")` at top of file |
| `Humanoid:LoadAnimation` | `Animator:LoadAnimation` |
| `part.Velocity` | `AssemblyLinearVelocity` |
| `Ray` + `FindPartOnRay`, `Region3` | `workspace:Raycast`, `GetPartBoundsInBox/Radius` |
| `type(x)` for Roblox types | `typeof(x)` |
| `tick()` | `os.clock()` / `os.time()` |
| global variables | `local` (module scope) |

## Style (matches this pack)
- Module public functions and Instance-facing APIs: PascalCase (`Init`, `Start`, `Register`). Locals, parameters, local functions: camelCase. Types, classes: PascalCase. Constants: UPPER_SNAKE. Private fields: `_name`.
- Services cached at top of file. Config via a frozen table (`table.freeze`).

## Anti-patterns worth flagging
- Replacing a 0.1 s poll with per-frame `Heartbeat` is **worse**. Use an event if one exists; else poll slowly (see roblox-optimization).
- Concatenating in a long loop: collect into a table, `table.concat` once. A few concatenations or interpolation are fine.
- Trusting client values; missing pcall on DataStore/HTTP; unbounded `while true` without a yield.
