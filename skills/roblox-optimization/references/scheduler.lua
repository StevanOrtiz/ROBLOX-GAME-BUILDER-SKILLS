--!strict
-- Scheduler: many tasks, one RunService connection, per-task rate, error isolation.
-- Drop into ReplicatedStorage/Shared/Util. Server and client each get their own copy at runtime.
local RunService = game:GetService("RunService")

type Entry = { fn: (dt: number) -> (), interval: number, acc: number }

local Scheduler = {}

local entries: { [string]: Entry } = {}
local queued: { [string]: Entry } = {}
local count = 0
local connection: RBXScriptConnection? = nil

local function step(dt: number)
	-- merge registrations queued during the previous step (adding keys mid-traversal is unsafe)
	for id, e in queued do
		if not entries[id] then count += 1 end
		entries[id] = e
		queued[id] = nil
	end
	for id, e in entries do
		e.acc += dt
		if e.acc >= e.interval then
			local elapsed = e.acc
			e.acc = 0
			debug.profilebegin(id)
			local ok, err = pcall(e.fn, elapsed)
			debug.profileend()
			if not ok then warn(`[Scheduler] {id} failed: {err}`) end
		end
	end
	if count == 0 and next(queued) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- hz = nil -> every frame. Registering an existing id replaces it.
function Scheduler.Register(id: string, fn: (dt: number) -> (), hz: number?)
	queued[id] = { fn = fn, interval = if hz then 1 / hz else 0, acc = 0 }
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

function Scheduler.Unregister(id: string)
	queued[id] = nil
	if entries[id] then
		entries[id] = nil -- assigning nil to an existing key is safe during traversal
		count -= 1
	end
end

return Scheduler
-- Use:
--   Scheduler.Register("EnemyAI", function(dt) ... end, 10) -- 10 Hz
--   Scheduler.Unregister("EnemyAI")
-- Client visuals tied to the camera: use RunService:BindToRenderStep instead.
