--!nonstrict
-- Project scanner. Run ONCE via execute_luau (edit mode). Does not yield. Returns a compact report string.
-- Static heuristics: every hit is a CANDIDATE to confirm by reading that line, not a verdict.
local PER_CAT = 6          -- max examples listed per category
local BIG_SCRIPT = 300     -- lines

local HOT = { "Heartbeat", "RenderStepped", "Stepped" }
local SERVICES = { "Players", "ReplicatedStorage", "ServerStorage", "ServerScriptService", "RunService",
	"UserInputService", "TweenService", "Lighting", "SoundService", "CollectionService", "DataStoreService",
	"HttpService", "MarketplaceService", "Debris", "StarterGui", "StarterPlayer", "PhysicsService" }
local SERVER_ONLY = { "DataStoreService", "OnServerEvent", "OnServerInvoke", "ProcessReceipt", "ServerStorage", "MessagingService" }

local function stripComment(line)
	return (line:gsub("%-%-.*$", ""))
end

-- true if `name(` appears as a bare call (not task.wait / obj:wait / foo_wait)
local function bareCall(code, name)
	local init = 1
	while true do
		local i, j = code:find(name .. "%s*%(", init)
		if not i then return false end
		local prev = i > 1 and code:sub(i - 1, i - 1) or ""
		if prev == "" or not prev:match("[%w_%.:]") then return true end
		init = j + 1
	end
end

local function firstSegment(path) return path:match("^[^%.]+") or path end

-- files: array of { path=, class=, src=, runContext= } ; stats: { parts=, unanchored=, streaming=, remotes={...} }
local function analyze(files, stats)
	local F, counts = {}, {}
	local function add(cat, path, line, note)
		counts[cat] = (counts[cat] or 0) + 1
		F[cat] = F[cat] or {}
		if #F[cat] < PER_CAT then
			table.insert(F[cat], string.format("%s:%d%s", path, line, note and (" " .. note) or ""))
		end
	end

	local byClass, strictCount, totalLines, unreadable = {}, 0, 0, 0
	local modules, requires = {}, {}      -- name -> true ; scriptPath -> { targetName = true }
	local lineSeen = {}                   -- normalized line -> { [path]=true, n= }
	local hotTotal = 0

	for _, f in ipairs(files) do
		byClass[f.class] = (byClass[f.class] or 0) + 1
		if f.class == "ModuleScript" then modules[f.path:match("([^%.]+)$")] = true end
	end

	for _, f in ipairs(files) do
		local path, src = f.path, f.src
		local top = firstSegment(path)
		if not src then
			unreadable += 1
		else
			local lines = src:split("\n")
			totalLines += #lines
			if #lines > BIG_SCRIPT then add("big_script", path, 1, "(" .. #lines .. " lines)") end

			local head = table.concat(lines, "\n", 1, math.min(3, #lines))
			if head:find("%-%-!strict") then strictCount += 1 end

			-- placement
			if f.class == "Script" and f.runContext == "Legacy" then
				if top == "Workspace" then
					add("placement", path, 1, "Script in Workspace (move to ServerScriptService)")
				elseif top == "ReplicatedStorage" or top == "StarterGui" or top == "StarterPlayer" or top == "ReplicatedFirst" then
					add("placement", path, 1, "server Script in client-side container: will not run")
				end
			elseif f.class == "LocalScript" and (top == "ServerScriptService" or top == "ServerStorage") then
				add("placement", path, 1, "LocalScript on server side: will not run")
			end
			if f.class == "ModuleScript" and (top == "ReplicatedStorage" or top == "ReplicatedFirst" or top == "StarterGui") then
				for _, key in ipairs(SERVER_ONLY) do
					if src:find(key, 1, true) then
						add("server_logic_exposed", path, 1, "uses " .. key .. " in a client-visible container")
						break
					end
				end
			end

			local hotHere = 0
			local seenReq = {}
			for n, line in ipairs(lines) do
				local code = stripComment(line)
				local indent = #(line:match("^%s*"))

				for _, name in ipairs({ "wait", "spawn", "delay" }) do
					if bareCall(code, name) then add("deprecated_global", path, n, name .. "(") end
				end
				if code:find("Instance%.new%(%s*[\"'][%w]+[\"']%s*,") then add("instance_new_parent_arg", path, n) end
				for _, s in ipairs(SERVICES) do
					if code:find("game%." .. s .. "%f[^%w_]") then add("game_dot_service", path, n, "game." .. s) end
				end
				if code:find("^%s*pcall%(") then add("bare_pcall", path, n, "result discarded") end
				if code:find("while%s+true%s+do") then add("while_true", path, n, "polling loop? prefer events") end

				for _, h in ipairs(HOT) do
					if code:find(h .. ":Connect%(") then hotHere += 1 end
				end

				-- unstored :Connect inside a function body (can leak if the function runs repeatedly)
				local pos = code:find(":Connect%(")
				if pos and indent > 0 then
					local h = code:sub(1, pos)
					if not (h:find("=") or h:find("^%s*return") or h:find("[Aa]dd%(") or h:find("insert%(")
						or h:find("[Cc]lean") or h:find("[Mm]aid") or h:find("[Tt]rove")) then
						add("unstored_connect", path, n, "(confirm it runs repeatedly)")
					end
				end

				-- remote handlers: look for type validation inside the handler body (max 12 lines)
				if code:find("OnServerEvent:Connect%(") or code:find("OnServerInvoke%s*=") then
					local last = n
					for k = n + 1, math.min(n + 12, #lines) do
						local l = lines[k]
						if l:find("%S") and #(l:match("^%s*")) <= indent then break end
						last = k
					end
					local window = table.concat(lines, "\n", n, last)
					if not (window:find("typeof%(") or window:find("type%(") or window:find("assert%(")) then
						add("remote_unvalidated", path, n, "no typeof/assert in handler body")
					end
				end

				-- requires (module name graph, approximate)
				for expr in code:gmatch("require%(([^%)]+)%)") do
					local target = expr:match("WaitForChild%(%s*[\"']([%w_]+)[\"']") or expr:match("([%w_]+)%s*$")
					if target and modules[target] and not seenReq[target] then
						seenReq[target] = true
						requires[path] = requires[path] or {}
						requires[path][target] = true
					end
				end

				-- duplicate-line candidates
				local norm = code:gsub("%s+", " ")
				if #norm >= 40 and not norm:find("GetService%(") and not norm:find("require%(") then
					local rec = lineSeen[norm]
					if not rec then rec = { paths = {}, n = 0 }; lineSeen[norm] = rec end
					if not rec.paths[path] then rec.paths[path] = n; rec.n += 1 end
				end
			end
			hotTotal += hotHere
			if hotHere >= 2 then add("multi_hot_connect", path, 1, hotHere .. " per-frame connections") end
		end
	end

	-- cycles in the require graph (module name approximation)
	local nameOf = function(path) return path:match("([^%.]+)$") end
	local graph = {}
	for p, targets in pairs(requires) do
		if modules[nameOf(p)] then graph[nameOf(p)] = graph[nameOf(p)] or {}
			for t in pairs(targets) do graph[nameOf(p)][t] = true end
		end
	end
	local state, cycles = {}, {}
	local function dfs(node, stack)
		state[node] = 1
		table.insert(stack, node)
		for nxt in pairs(graph[node] or {}) do
			if state[nxt] == 1 and #cycles < 3 then
				local from = table.find(stack, nxt)
				local cyc = {}
				for i = from, #stack do table.insert(cyc, stack[i]) end
				table.insert(cyc, nxt)
				table.insert(cycles, table.concat(cyc, " -> "))
			elseif not state[nxt] then
				dfs(nxt, stack)
			end
		end
		table.remove(stack)
		state[node] = 2
	end
	for node in pairs(graph) do if not state[node] then dfs(node, {}) end end

	-- duplicate lines present in 3+ different scripts
	local dups = {}
	for norm, rec in pairs(lineSeen) do
		if rec.n >= 3 then table.insert(dups, { norm = norm, n = rec.n }) end
	end
	table.sort(dups, function(a, b) return a.n > b.n end)

	-- assemble
	local out = {}
	local classes = {}
	for c, n in pairs(byClass) do table.insert(classes, c .. "=" .. n) end
	table.sort(classes)
	table.insert(out, string.format("SCRIPTS %d (%s) lines=%d strict=%d%% unreadable=%d", #files, table.concat(classes, " "),
		totalLines, #files > 0 and math.floor(100 * strictCount / #files) or 0, unreadable))
	if stats then
		table.insert(out, string.format("WORKSPACE parts=%s unanchored=%s streaming=%s remotes=%s",
			tostring(stats.parts), tostring(stats.unanchored), tostring(stats.streaming), tostring(stats.remotes)))
	end
	table.insert(out, "HEARTBEAT-like connections total=" .. hotTotal)

	local order = { "remote_unvalidated", "server_logic_exposed", "placement", "unstored_connect", "multi_hot_connect",
		"deprecated_global", "instance_new_parent_arg", "game_dot_service", "bare_pcall", "while_true", "big_script" }
	for _, cat in ipairs(order) do
		if counts[cat] then
			table.insert(out, string.format("[%s] %d", cat, counts[cat]))
			for _, ex in ipairs(F[cat]) do table.insert(out, "  " .. ex) end
		end
	end
	if #cycles > 0 then
		table.insert(out, "[circular_requires] " .. #cycles .. " (approx, by module name)")
		for _, c in ipairs(cycles) do table.insert(out, "  " .. c) end
	end
	if #dups > 0 then
		table.insert(out, "[duplicate_lines in 3+ scripts] " .. #dups)
		for i = 1, math.min(3, #dups) do table.insert(out, string.format("  x%d  %s", dups[i].n, dups[i].norm:sub(1, 70))) end
	end
	return table.concat(out, "\n")
end

-- ===== ROBLOX COLLECTION =====
local function collect()
	local files = {}
	local roots = { "Workspace", "ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst",
		"StarterGui", "StarterPlayer", "StarterPack" }
	local parts, unanchored = 0, 0
	for _, rootName in ipairs(roots) do
		local root = game:GetService(rootName)
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("LuaSourceContainer") then
				local ok, src = pcall(function() return inst.Source end)
				local rc = "Legacy"
				if inst:IsA("Script") then
					local okc, v = pcall(function() return inst.RunContext.Name end)
					if okc then rc = v end
				end
				table.insert(files, { path = inst:GetFullName(), class = inst.ClassName, src = ok and src or nil, runContext = rc })
			elseif rootName == "Workspace" and inst:IsA("BasePart") then
				parts += 1
				if not inst.Anchored then unanchored += 1 end
			end
		end
	end
	local remotes = 0
	for _, inst in ipairs(game:GetDescendants()) do
		if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then remotes += 1 end
	end
	return files, { parts = parts, unanchored = unanchored, streaming = workspace.StreamingEnabled, remotes = remotes }
end

local files, stats = collect()
return analyze(files, stats)
