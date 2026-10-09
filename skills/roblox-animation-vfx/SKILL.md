---
name: roblox-animation-vfx
description: Rules and ready modules for Roblox character/NPC animation (Animator, priorities, markers, AnimationController), particle effects (ParticleEmitter presets), beams and trails, TweenService feedback, lighting and post-processing mood, sound/positional audio, camera effects (shake, zoom, cutscenes) and combined hit feedback. Use whenever the user asks for an animation to play, an effect (fire, smoke, sparkles, rain, snow, aura, explosion, laser, sword trail), hit feedback / game "juice", screen shake, a cutscene, atmosphere or lighting mood, or sound tied to actions. Server decides, clients render effects. Persistent world effects are built live through the MCP.
---

# Animation, VFX, sound, camera

## Golden rules
- **Server decides, client renders.** Server validates the hit/event and fires a remote. Each client builds the effect locally (particles, tweens, shake, flash). Server-made visuals replicate to everyone and cost bandwidth.
- **Persistent world FX** (torch fire, ambient smoke, lighting) are created once as live instances via `execute_luau` (idempotent), not by a script at runtime.
- **Data over code.** Effects are presets (a table of numbers), built by one function: `references/fx-presets.lua`. Don't hand-write 30 property lines per effect.
- **Perf budgets** live in `roblox-optimization`. Don't blow them with decorative FX.
- Code location per `roblox-architecture`: client FX in `StarterPlayerScripts` (an `FxController` with `Init/Start` + helper modules), data/presets in `ReplicatedStorage/Shared`.

## Animation (details: `references/animation.md`)
- Load through the **Animator** (`humanoid.Animator`, or an `Animator` inside an `AnimationController` for non-humanoid rigs). `Humanoid:LoadAnimation` and `AnimationController:LoadAnimation` are deprecated.
- Load each track **once per character**, cache it, set `Priority`, preload with `ContentProvider:PreloadAsync`. Never `LoadAnimation` inside the attack handler.
- Priority low -> high: `Core` (engine defaults, lowest), `Idle`, `Movement`, `Action`, `Action2`, `Action3`, `Action4`.
- Animation assets must be owned by the game's owner (user or group) or they won't play. Wrong-owner is the #1 "my animation does nothing" cause.
- Player character: play on the **client** (responsive, replicates). NPCs: play on the **server**.
- Gameplay timing (hitbox, sound, particle) comes from `GetMarkerReachedSignal("Name")`, connected once per track. Never from `task.wait` guesses.

## Particles
- Build with a preset: `Presets.Build("fire", attachmentOrPart)`. Override only the fields that differ.
- Parent to an `Attachment` to control the emit point; to a Part to emit from its volume (size matters).
- One-shot bursts: emitter with `Rate = 0` and `:Emit(n)`. Never create emitters per event or per frame.
- Weather (rain/snow): client-only, one emitter on a non-colliding anchored part that follows the camera, never a map-sized part. Set `CanCollide/CanQuery/CanTouch = false`.
- Built-in textures like `rbxasset://textures/particles/*.dds` may change; confirm it loads, otherwise use your own asset ids.
- Texture sizes and rates: see `roblox-optimization`.

## Beams / Trails
- Beam: two `Attachment`s; `FaceCamera = true`; `Segments` modest; scroll texture with `TextureSpeed`. Lightning: randomize `CurveSize0/1` at ~20 Hz, not every frame.
- Trail: two attachments on the **same** part define its width. Short `Lifetime` (0.2-0.4 s). Toggle `Enabled` with the swing instead of recreating.

## TweenService
- Visual tweens run on the **client**. A server tween replicates every step.
- Chain with `tween.Completed:Once(...)` or `:Wait()` inside a `task.spawn`, not nested `:Connect`.
- Re-triggering: cancel the running tween first and capture the original value **once**. (Capturing "original" mid-tween makes a flash stick white.)
- Don't tween `Size` on welded/unanchored assemblies (breaks joints). Use `Model:ScaleTo`, or tween an anchored visual part.
- Hit flash: use a `Highlight` fill tween on the model, not Color mutation. Keep few Highlights active at once (the docs page doesn't state a cap, but they are limited).

## Lighting / post-processing
- Static mood is scene setup: apply once via `execute_luau` with `references/lighting-presets.lua` (idempotent), not a runtime script. One of each PostEffect per class.
- Dynamic lights: `Shadows = false` unless essential. Few lights, small `Range`.

## Sound
- Positional: Sound parented to a Part/Attachment with RollOff settings. Global music: parent to `SoundService`. Volume categories via `SoundGroup` in `SoundService`.
- Reuse Sound objects (e.g. one per footstep slot, vary `PlaybackSpeed`) instead of `Instance.new` per play. If one-shots are created, destroy on `Ended` **and** with a timeout fallback (failed loads never fire `Ended`).
- UI/local-only sounds: `SoundService:PlayLocalSound`.
- Audio asset ids must be usable by the experience (owned or public); otherwise silent.

## Camera (`references/camera-fx.lua`)
- Shake via `Humanoid.CameraOffset` bound after the camera script. Don't write `camera.CFrame` from a plain `RenderStepped`: the camera script overwrites it or the offset accumulates.
- One shaker; a new shake only replaces a weaker one. Expose an `Enabled` flag for a "reduce camera shake" setting.
- Cutscenes: set `Scriptable`, always restore the previous `CameraType` (also on error), allow skip.
- Restore FOV to the saved base, not a hard-coded number.

## Hit feedback (`references/hit-effect.lua`)
Server validates hit -> `HitConfirmed` remote -> client `HitEffect.Play(part, opts)` = Highlight flash + particle burst + one-shot sound + (optional) shake. Shake only when the local player is attacker or victim.

## Quality scaling
Read the player's quality with `.Value` of the enums (they are not numbers). Low: disable post effects, halve emitter `Rate`, skip shake. Use one `ApplyQuality()` called at start and when the setting changes.

## Via MCP
1. Static scene (lighting, ambient emitters, atmosphere): one `execute_luau` using the presets file, returns what it set.
2. Runtime FX: write/patch the client module with `multi_edit`; one playtest, read `[Fx]`-tagged console lines.
3. Record new instance paths in `GAMEMAP.md`. Short report per `ihaveadhd`.

## Don't
Unbounded emitters, per-frame `Instance.new` for FX, server-side visual tweens, camera shake that keeps running or leaves `Scriptable`, animation loading in hot paths, many shadow-casting lights.
