# Genre playbooks (read one section only)

## Incremental / simulator / tycoon
- Economy math in a pure module driven by `Config` tables (costs, multipliers, rebirth curves). Server computes income; client only displays.
- Tick income at ~1 Hz through a scheduler (roblox-optimization), not per-frame.
- Big numbers: doubles are exact only to ~9e15. Beyond that store `{mantissa, exponent}` (or a BigNum module) and format with a suffix table (K, M, B, T...). Decide this before the first save format.
- Offline progress: save `os.time()` on leave; on join grant `min(elapsed, CAP) * rate`.
- Rebirth/prestige and upgrades are data (id -> level), versioned for migration.
- Data is the product: `UpdateAsync` + session lock + autosave (60-120 s) + `BindToClose`.
- Monetization: multipliers derived server-side from owned passes; idempotent `ProcessReceipt`.
- Exploits: rate-limit clicks/collects; never accept client-reported currency or totals.
- UI: counters update at <= 10 Hz from deltas; list items from templates; big tap targets.

## Obby / parkour / maps
- Checkpoints and stage order validated on the server; respawn point stored per player.
- Kill planes, timers and finish detection server-side; moving hazards on anchored parts, keep part count and unanchored parts low.
- Anti-exploit: speed/teleport sanity checks between checkpoints.
- Large maps: StreamingEnabled and a part budget (mobile floor). Prove reachability when it matters (jump distances vs `Humanoid` jump power).
- Section/stage content as data so levels are added without new code.

## Combat / shooter / PvP
- Server owns weapon stats, cooldown, range and hit validation (raycast/line of sight). Client sends intent ("attack target X") and may predict visuals.
- Animations on the client for the local player; hit timing from animation markers; effects via `HitConfirmed` remote -> client FX.
- Rate-limit attack remotes; tolerate small latency in range checks.
- Anti-exploit: movement speed/fly checks, no client-supplied damage or hit positions.
- Performance: pool projectiles, cap simultaneous effects, throttle replicated state.

## RPG / adventure
- Quests, dialogue, items and zones are data (id-keyed tables in `Shared`), executed by small Services.
- Inventory service with server-side item definitions; versioned save schema (it will change).
- NPC behavior at 5-10 Hz via the scheduler; cutscenes through `CameraFx`; streaming for big worlds.
- State machines for quests (explicit states, no scattered booleans).
