--!strict
-- Main (Script in ServerScriptService). Loads every ModuleScript under Services,
-- runs all Init, then all Start. Client version: same code, folder = StarterPlayerScripts.Controllers (LocalScript).
local ServerScriptService = game:GetService("ServerScriptService")

local function trace(e: any): string
	return debug.traceback(tostring(e), 2)
end

type Module = { Init: (() -> ())?, Start: (() -> ())? }

local folder = ServerScriptService:WaitForChild("Services")
local loaded: { { name: string, mod: Module } } = {}

for _, child in folder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, mod = xpcall(require, trace, child)
		if ok then
			table.insert(loaded, { name = child.Name, mod = mod :: Module })
		else
			warn(`[Main] load {child.Name} failed: {mod}`)
		end
	end
end

for _, entry in loaded do
	if entry.mod.Init then
		local ok, err = xpcall(entry.mod.Init :: () -> any, trace)
		if not ok then warn(`[Main] {entry.name}.Init failed: {err}`) end
	end
end

for _, entry in loaded do
	if entry.mod.Start then
		-- spawn so one yielding Start can't block the others
		task.spawn(function()
			local ok, err = xpcall(entry.mod.Start :: () -> any, trace)
			if not ok then warn(`[Main] {entry.name}.Start failed: {err}`) end
		end)
	end
end

print("[Main] started", #loaded, "modules")
