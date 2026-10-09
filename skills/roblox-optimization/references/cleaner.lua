--!strict
-- Cleaner: collect anything that must be released later, release in reverse order.
-- Drop into ReplicatedStorage/Shared/Util.
local Cleaner = {}
Cleaner.__index = Cleaner

export type Cleaner = typeof(setmetatable({} :: { _items: { any } }, Cleaner))

function Cleaner.new(): Cleaner
	return setmetatable({ _items = {} }, Cleaner)
end

-- Accepts: RBXScriptConnection, Instance, function, thread, or table with :Destroy()
function Cleaner.Add<T>(self: Cleaner, item: T): T
	table.insert(self._items, item)
	return item
end

function Cleaner.Clean(self: Cleaner)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local item: any = items[i]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			if item.Connected then item:Disconnect() end
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			(item :: () -> ())()
		elseif kind == "thread" then
			task.cancel(item)
		elseif kind == "table" and (item :: any).Destroy then
			(item :: any):Destroy()
		end
	end
end

Cleaner.Destroy = Cleaner.Clean

return Cleaner
-- Use:
--   local c = Cleaner.new()
--   c:Add(Players.PlayerRemoving:Connect(onLeave))
--   c:Add(someFolder)
--   c:Clean() -- on teardown / player leave
