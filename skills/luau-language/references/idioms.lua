--!strict
-- Luau idioms. Copy the piece you need; this is a snippet bank, not a module.

----------------------------------------------------------------------
-- 1. Class that type-checks in --!strict (fields live in the constructor literal)
----------------------------------------------------------------------
local Weapon = {}
Weapon.__index = Weapon

export type Weapon = typeof(setmetatable({} :: {
	name: string,
	damage: number,
	durability: number,
	maxDurability: number,
}, Weapon))

function Weapon.new(name: string, damage: number, durability: number): Weapon
	return setmetatable({
		name = name,
		damage = damage,
		durability = durability,
		maxDurability = durability,
	}, Weapon)
end

function Weapon.Attack(self: Weapon, target: Humanoid): boolean
	if self.durability <= 0 then return false end
	self.durability -= 1
	target:TakeDamage(self.damage)
	return true
end

----------------------------------------------------------------------
-- 2. Composition instead of inheritance: an Enemy HAS a Health
----------------------------------------------------------------------
local Health = {}
Health.__index = Health

export type HealthT = typeof(setmetatable({} :: { current: number, max: number }, Health))

function Health.new(max: number): HealthT
	return setmetatable({ current = max, max = max }, Health)
end

function Health.Damage(self: HealthT, amount: number)
	self.current = math.max(0, self.current - amount)
end

function Health.IsAlive(self: HealthT): boolean
	return self.current > 0
end

local Enemy = {}
Enemy.__index = Enemy

export type EnemyT = typeof(setmetatable({} :: {
	health: HealthT,
	attackDamage: number,
	position: Vector3,
}, Enemy))

function Enemy.new(maxHealth: number, attackDamage: number, position: Vector3): EnemyT
	return setmetatable({
		health = Health.new(maxHealth),
		attackDamage = attackDamage,
		position = position,
	}, Enemy)
end

function Enemy.Attack(self: EnemyT, targetHealth: HealthT, targetPosition: Vector3, range: number)
	if (targetPosition - self.position).Magnitude <= range then
		targetHealth:Damage(self.attackDamage)
	end
end

----------------------------------------------------------------------
-- 3. Retry a fallible call with exponential backoff (DataStore, HTTP, Marketplace)
----------------------------------------------------------------------
local function retry<T>(attempts: number, baseDelay: number, fn: () -> T): (boolean, T | string)
	local lastError = "no attempts"
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		if attempt < attempts then
			task.wait(baseDelay * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end
-- local ok, data = retry(3, 1, function() return store:GetAsync(key) end)
-- if not ok then warn("[Data] load failed: " .. tostring(data)) end

----------------------------------------------------------------------
-- 4. Deep copy that survives cycles (metatables are NOT preserved)
----------------------------------------------------------------------
local function deepCopy<T>(value: T, seen: { [any]: any }?): T
	local source: any = value
	if typeof(source) ~= "table" then
		return value
	end
	local visited: { [any]: any } = seen or {}
	if visited[source] then
		return visited[source]
	end
	local copy: { [any]: any } = {}
	visited[source] = copy
	for k, v in source do
		copy[deepCopy(k, visited)] = deepCopy(v, visited)
	end
	return copy :: any
end

----------------------------------------------------------------------
-- 5. Small ones
----------------------------------------------------------------------
local NONE = table.freeze({}) -- sentinel: "looked it up, nothing there" (a nil value can't be stored)

local function joinAny(values: { any }, sep: string): string
	local parts = table.create(#values)
	for i, v in values do
		parts[i] = tostring(v)
	end
	return table.concat(parts, sep)
end

local function roundTo(value: number, places: number): number
	local factor = 10 ^ places
	return math.round(value * factor) / factor
end

local function remap(v: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	return outMin + (outMax - outMin) * ((v - inMin) / (inMax - inMin))
end

return {
	Weapon = Weapon, Health = Health, Enemy = Enemy,
	retry = retry, deepCopy = deepCopy, NONE = NONE,
	joinAny = joinAny, roundTo = roundTo, remap = remap,
}
