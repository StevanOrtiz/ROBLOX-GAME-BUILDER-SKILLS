# Animation reference (corrected)

## Get the Animator
```lua
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator") :: Animator
```
Non-humanoid rig: `AnimationController` + an **`Animator` child** inside it; load tracks from that Animator.

## Load once, cache, play
```lua
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://ID"     -- asset must be owned by the game's owner/group
local track = animator:LoadAnimation(anim)
track.Priority = Enum.AnimationPriority.Action
ContentProvider:PreloadAsync({ anim })    -- avoid first-play hitch

track:Play(0.1)                           -- fade in
track:Stop(0.2)                           -- fade out
track:AdjustSpeed(1.5)
track:AdjustWeight(0.8)
```
Do this once per character spawn (e.g. `CharacterAdded`), store tracks in a table keyed by name; the attack handler only calls `:Play()`. Tracks die with the character.

## Priorities (low -> high)
`Core` (engine defaults, lowest) < `Idle` < `Movement` < `Action` < `Action2` < `Action3` < `Action4`.
Equal priority: tracks blend by weight. Partial-body layering: author the upper-body animation with only upper joints keyed, give it `Action`, let legs keep `Movement`.

## Markers
```lua
track:GetMarkerReachedSignal("HitFrame"):Connect(function(param: string)
	-- hitbox / sound / particles for this exact frame
end)
```
Connect once after loading. Fires on the side that plays the track.

## Cross-fade
```lua
walk:Stop(0.3); run:Play(0.3)
```

## Client vs server
- Local player's character: play on the client.
- NPCs/props: play on the server.

## Custom rig (no Humanoid)
`Model` with `Motor6D` joints, a `PrimaryPart` root, an `AnimationController` containing an `Animator`. Animations are authored in the Animation Editor against that exact rig.
