# Communication templates

## Validated server handler (RemoteEvent)
```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuyItem = ReplicatedStorage.Remotes:WaitForChild("BuyItem") :: RemoteEvent
local lastCall: { [Player]: number } = {}

Players.PlayerRemoving:Connect(function(player) lastCall[player] = nil end)

BuyItem.OnServerEvent:Connect(function(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" then return end          -- type
	local now = os.clock()
	if now - (lastCall[player] or 0) < 0.25 then return end -- rate limit
	lastCall[player] = now
	-- existence, ownership, range, price: computed from SERVER data, then act
end)
```
Reject silently or `warn("[Shop] ...")`; never error on bad input.

## Client asks, server answers (RemoteFunction, client -> server only)
```lua
-- server
GetInventory.OnServerInvoke = function(player: Player)
	return DataService.GetInventory(player) -- return fast; never yield on external things
end
-- client
local inv = GetInventory:InvokeServer()
```

## Server asks client: two RemoteEvents
Server fires `RequestX` to the client; client replies on `ReplyX`; server matches by request id and times out with `task.delay`. Never `InvokeClient`.

## Same-side decoupling (BindableEvent)
```lua
local RoundEnded = Instance.new("BindableEvent") -- created once, in the owning Service
RoundEnded:Fire(winnerTeam, score)
RoundEnded.Event:Connect(function(winnerTeam, score) end)
```

## Unreliable, throttled (cosmetic only)
```lua
-- client: ~15 Hz, not every frame
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 1 / 15 then return end
	acc = 0
	CursorPosition:FireServer(UserInputService:GetMouseLocation())
end)
```
Server validates `typeof(pos) == "Vector2"` and clamps before relaying. Docs: payloads over 1,000 bytes may be dropped; delivery and order are not guaranteed, so include a sequence number and ignore older messages.
