--!strict
-- ObjectPool: reuse instances that spawn/despawn often. Drop into ReplicatedStorage/Shared/Util.
local ObjectPool = {}
ObjectPool.__index = ObjectPool

type Pool = typeof(setmetatable({} :: {
	_template: Instance,
	_free: { Instance },
	_active: { [Instance]: boolean },
	_reset: ((Instance) -> ())?,
	_max: number,
}, ObjectPool))

-- reset: optional, restores per-use state (velocity, transparency, particles...)
function ObjectPool.new(template: Instance, initialSize: number, reset: ((Instance) -> ())?, maxFree: number?): Pool
	local self = setmetatable({
		_template = template,
		_free = table.create(initialSize),
		_active = {},
		_reset = reset,
		_max = maxFree or initialSize * 2,
	}, ObjectPool)
	for _ = 1, initialSize do
		table.insert(self._free, template:Clone())
	end
	return self
end

function ObjectPool.Get(self: Pool): Instance
	local obj = table.remove(self._free) or self._template:Clone()
	self._active[obj] = true
	return obj
end

function ObjectPool.Return(self: Pool, obj: Instance)
	if not self._active[obj] then return end
	self._active[obj] = nil
	obj.Parent = nil
	if obj:IsA("BasePart") then
		obj.AssemblyLinearVelocity = Vector3.zero
		obj.AssemblyAngularVelocity = Vector3.zero
	end
	if self._reset then self._reset(obj) end
	if #self._free >= self._max then
		obj:Destroy() -- cap pool growth
	else
		table.insert(self._free, obj)
	end
end

function ObjectPool.ReturnAll(self: Pool)
	local snapshot = {}
	for obj in self._active do table.insert(snapshot, obj) end
	for _, obj in snapshot do self:Return(obj) end
end

function ObjectPool.Destroy(self: Pool)
	for obj in self._active do obj:Destroy() end
	for _, obj in self._free do obj:Destroy() end
	table.clear(self._active)
	table.clear(self._free)
end

return ObjectPool
-- Use:
--   local pool = ObjectPool.new(ReplicatedStorage.Assets.Bullet, 50)
--   local b = pool:Get(); b.CFrame = cf; b.Parent = workspace
--   pool:Return(b)
