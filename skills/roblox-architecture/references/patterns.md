# Module patterns

## Service skeleton
```lua
--!strict
-- InventoryService: per-player inventories (server)
local Players = game:GetService("Players")

local InventoryService = {}
local inventories: { [Player]: { [string]: number } } = {}

function InventoryService.Init()
	Players.PlayerRemoving:Connect(function(player) inventories[player] = nil end)
end

function InventoryService.Add(player: Player, itemId: string, qty: number)
	local inv = inventories[player]
	if not inv then inv = {}; inventories[player] = inv end
	inv[itemId] = (inv[itemId] or 0) + qty
end

function InventoryService.Get(player: Player, itemId: string): number
	local inv = inventories[player]
	return if inv then (inv[itemId] or 0) else 0
end

return InventoryService
```

## Class module
```lua
--!strict
local Weapon = {}
Weapon.__index = Weapon

export type Weapon = typeof(setmetatable({} :: {
	name: string, damage: number, cooldown: number, _lastFired: number,
}, Weapon))

function Weapon.new(name: string, damage: number, cooldown: number): Weapon
	return setmetatable({ name = name, damage = damage, cooldown = cooldown, _lastFired = 0 }, Weapon)
end

function Weapon.Fire(self: Weapon): number?
	if os.clock() - self._lastFired < self.cooldown then return nil end
	self._lastFired = os.clock()
	return self.damage
end

return Weapon
```

## Breaking a circular require (pass dependency in Init)
```lua
local B -- set in Init
function A.Init(deps) B = deps.B end
function A.DoThing() B.Helper() end
```
Prefer extracting a third module C first; use this only when a real two-way link remains.
