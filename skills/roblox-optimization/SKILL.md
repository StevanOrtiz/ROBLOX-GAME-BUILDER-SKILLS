---
name: roblox-optimization
description: Performance and memory rules for Roblox games - per-frame cost, memory leaks, remote/network bandwidth, physics and rendering load, mobile limits, and how to profile (MicroProfiler, F9, Stats, debug.profilebegin). Use when the user reports lag, low FPS, stutter, high ping, memory growth, or a mobile performance problem, asks to optimize or profile, or when you are about to write hot code (per-frame loops, many NPCs/projectiles, high-frequency remotes, spawn/despawn). Don't pre-optimize cold code: measure first, fix the hot path only.
---

# Roblox optimization

## 0. Measure first
No numbers = no optimization. Pick the tool by symptom:

| Symptom | Tool | Look at |
|---|---|---|
| Low FPS / stutter | MicroProfiler (Ctrl+F6, Ctrl+P pause) | Widest bar: script (Heartbeat), Physics, Render, Replication |
| Memory grows | F9 > Memory; `Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.X)` | Which tag grows over minutes |
| High ping / data | F9 > Stats (send/recv KB/s) | Which remote fires most |

- Label your own code so it shows in MicroProfiler: `debug.profilebegin("Name") ... debug.profileend()`.
- Via MCP you can't open the profiler. Ask the user for the MicroProfiler finding or F9 numbers, or print `os.clock()` deltas / `Stats` with a `[Perf]` tag and read `get_console_output` once. `execute_luau` with `datamodel_type = Server` or `Client` can run inside the running game during Play; `Edit` measures the edit session, not gameplay.
- Fix the biggest bar only. Re-measure once.

## 1. Per-frame code
- Cost is the work done per frame, not the number of `Heartbeat` connections. Merge loops only when it lets you throttle or isolate them: `references/scheduler.lua` (rate per task, pcall isolation, zero cost when idle).
- Most logic does not need 60 Hz: AI, UI refresh, proximity checks at 5-20 Hz.
- Prefer events (`Changed`, `ChildAdded`, remotes, `GetPropertyChangedSignal`) over polling.
- Cache refs outside loops (`GetService`, `FindFirstChild`, `WaitForChild`). Re-validate with `inst.Parent`. `GetService` is cheap; this is for clarity, not speed.
- Don't allocate per frame: no `Instance.new`, no new tables/closures in hot loops, reuse and `table.clear`.
- Build strings with `table.concat`; pre-size arrays with `table.create(n)` when n is known.
- Spatial queries, never scans: `workspace:GetPartBoundsInRadius/InBox` + `OverlapParams` with an Include list. No `GetDescendants()`/`GetChildren()` loops on big containers.
- Heavy pure math: `--!native` / `@native` after profiling shows it hot.
- Create instances with properties set first and `Parent` last.

## 2. Memory
- Every `:Connect` result is stored and disconnected: `references/cleaner.lua` (connections, instances, functions, threads).
- `:Destroy()`, not `Parent = nil`. Destroy also disconnects the instance's own events. Timed: `task.delay(t, function() inst:Destroy() end)` (or Debris).
- Leaks come from live roots: unremoved connections, module tables holding dead instances/players, closures. Clear per-player tables on `PlayerRemoving`.
- Lua's GC handles reference cycles. Don't hand-break them.
- Spawn/despawn often (bullets, VFX, pickups) -> `references/object-pool.lua`. Not for rare objects.
- Detect a leak: memory still climbing after several minutes of steady play. A one-off spike is not a leak.

## 3. Network
- Send on change, not every frame. Send deltas (`{added, removed}`), not full state.
- Related values that change together go in one call. Unrelated ones stay separate.
- Shrink payloads: arrays or numeric ids over string-keyed tables; `buffer` for dense data; no Instance refs when an id works.
- `UnreliableRemoteEvent` for lossy, high-frequency, stale-is-fine data (cosmetic positions). Docs: messages over 1,000 bytes may be dropped, and neither delivery nor order is guaranteed. Keep packets small, 10-20 Hz, include a sequence number/timestamp and ignore older ones, never for gameplay-critical events.
- Visual-only effects (tweens, particle colors) run on the client. A server-side property change replicates to everyone.
- Rate-limit and validate remote handlers (see roblox-code-structure).

## 4. Physics and rendering
- Anchor everything that doesn't move. Decorative parts: `CanCollide/CanQuery/CanTouch = false`, `CastShadow = false` if small or far.
- Avoid `.Touched` on many parts; use region queries on a timer or collision groups.
- Fewer, larger parts and meshes beat many small ones. Use `MeshPart.RenderFidelity` and `StreamingEnabled` before hand-built LOD.
- Move models with `PivotTo`, not per-part CFrame writes.
- Particles: disable emitters out of view; fewer larger particles. Budgets below are starting points, not engine limits.

| Item | Start budget |
|---|---|
| Emitter Rate | <= ~200 |
| Emitters in view | <= ~20 |
| Beam Segments | 10-20 |
| Textures: props / hero / UI | 512 / 1024 / 256-512 px |

Texture memory depends on decoded resolution, not file format.

## 5. Mobile
- Treat mobile as the floor. Targets: ~30-50% fewer parts and lighter effects than desktop, as a starting point.
- Detect: `UserInputService.TouchEnabled and not KeyboardEnabled`. Halve particle rates, drop non-essential emitters.
- Touch targets >= 44x44; no hover-only UI.
- `StreamingTargetRadius/MinRadius` are documented as Not Scriptable: set them in Studio's Workspace properties, not from code, and not per device.
- Memory limits vary by device. Watch `Stats:GetTotalMemoryUsageMb()` trend, not one fixed number. Final check on real low-RAM hardware.

## 6. Don't
- Optimize without a measurement. Add a pool/scheduler "just in case".
- Create/destroy instances in Heartbeat.
- Send full tables every update.
- Recommend JPEG-vs-PNG savings, or "break cycles to free memory": neither helps.

## 7. Reporting
State: bottleneck found (tool + number), change made, expected effect. Ask for a re-measure. Per `ihaveadhd`: short.
