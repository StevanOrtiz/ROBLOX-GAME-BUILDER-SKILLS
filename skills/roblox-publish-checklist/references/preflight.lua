--!nonstrict
-- Publish preflight. Run ONCE via execute_luau (edit mode). Does not yield. Returns a compact report.
-- Static heuristics: FAIL/WARN lines are candidates to confirm by reading the cited line.
local PER_CAT = 5
local PRINT_SPAM = 40

local function strip(line) return (line:gsub("%-%-.*$", "")) end

-- files: { {path=, src=} } ; env: { placeId=, streaming=, minR=, targetR=, maxPlayers=, parts=, gui={total=, offsetOnly=, small={paths}} }
local function analyze(files, env)
	local R = { FAIL = {}, WARN = {}, INFO = {}, PASS = {} }
	local function out(level, name, detail) table.insert(R[level], name .. (detail and (": " .. detail) or "")) end
	local function check(ok, name, failLevel, failDetail)
		if ok then out("PASS", name) else out(failLevel, name, failDetail) end
	end

	local any = {}      -- feature -> true (seen anywhere)
	local ex = {}       -- category -> list of path:line
	local function note(cat, path, n)
		ex[cat] = ex[cat] or {}
		if #ex[cat] < PER_CAT then table.insert(ex[cat], path .. ":" .. n) end
		ex[cat].count = (ex[cat].count or 0) + 1
	end
	local prints, unreadable = 0, 0

	for _, f in ipairs(files) do
		if not f.src then
			unreadable += 1
		else
			local lines = f.src:split("\n")
			for n, raw in ipairs(lines) do
				local code = strip(raw)
				if code:find("DataStoreService") or code:find(":GetDataStore%(") then any.dataStore = true end
				if code:find("BindToClose") then any.bindToClose = true end
				if code:find("PlayerRemoving") then any.playerRemoving = true end
				if code:find("ProcessReceipt%s*=") then any.processReceipt = true end
				if code:find("PromptProductPurchase") or code:find("PromptGamePassPurchase") then any.prompts = true end
				if code:find("PurchaseGranted") then any.granted = true end
				if code:find("PurchaseId") then any.purchaseId = true end
				if code:find("NotProcessedYet") then any.notYet = true end
				if code:find("UserOwnsGamePassAsync") then any.ownsPass = true end
				if code:find("MembershipType") then any.premiumRead = true end
				if code:find("PlayerMembershipChanged") then any.premiumChanged = true end
				if code:find("FilterStringAsync") or code:find("TextChatService") or code:find("FilterAsync") then any.filter = true end
				if code:find("game%.JobId") or code:find("ProfileService") or code:find("ProfileStore") or code:find("[Ss]ession[Ll]ock") then any.lock = true end
				if code:find("[Vv]ersion%s*=") then any.version = true end
				if code:find("OrderedDataStore") or code:find("GetOrderedDataStore") then any.ordered = true end
				if code:find("AnalyticsService") then any.analytics = true end

				if code:find("print%(") then prints += 1 end
				if code:find("RunService:IsStudio%(") then note("isStudio", f.path, n) end
				if code:find("SetAsync%(") then note("setAsync", f.path, n) end

				if code:find(":GetAsync%(") or code:find(":SetAsync%(") or code:find(":UpdateAsync%(") or code:find(":IncrementAsync%(") then
					local from = math.max(1, n - 3)
					local window = table.concat(lines, "\n", from, n)
					if not window:find("pcall") then note("dsNoPcall", f.path, n) end
				end

				if code:find("loadstring") or code:find("getfenv") or code:find("setfenv") or code:find("require%(%s*%d+")
					or code:find("InsertService") or code:find(":LoadAsset") then
					note("backdoor", f.path, n)
				end
				if code:find("[Kk]ey%s*=%s*[\"'][%w_%-]{16,}[\"']") or code:find("[Tt]oken%s*=%s*[\"'][%w_%-%.]{16,}[\"']")
					or code:find("[Ss]ecret%s*=%s*[\"'][^\"']+[\"']") then
					note("secret", f.path, n)
				end
			end
		end
	end

	-- Data
	if any.dataStore then
		check(any.bindToClose, "BindToClose", "FAIL", "DataStore used but no BindToClose: players' last data is lost on shutdown")
		check(any.playerRemoving, "PlayerRemoving save", "FAIL", "no PlayerRemoving handler found")
		if ex.dsNoPcall then out("FAIL", "DataStore call without pcall nearby (" .. ex.dsNoPcall.count .. ")", table.concat(ex.dsNoPcall, ", ")) else out("PASS", "DataStore calls near pcall") end
		if ex.setAsync then out("WARN", "SetAsync used (" .. ex.setAsync.count .. ")", "prefer UpdateAsync; " .. table.concat(ex.setAsync, ", ")) end
		check(any.lock, "Session lock evidence", "WARN", "none found (JobId / ProfileStore / lock): risk of dupes or overwrites across servers")
		check(any.version, "Data version field", "WARN", "no version field found: schema changes will be painful")
	else
		out("INFO", "No DataStore usage found", "progress won't persist")
	end

	-- Monetization
	if any.prompts or any.processReceipt then
		check(any.processReceipt, "ProcessReceipt assigned", "FAIL", "products are prompted but nothing grants them")
		if any.processReceipt then
			check(any.granted, "Returns PurchaseGranted", "FAIL", "never returned")
			check(any.purchaseId, "Receipt dedupe (PurchaseId)", "WARN", "receipts can be delivered again: grant must be idempotent")
			check(any.notYet, "NotProcessedYet path", "WARN", "player gone / data not loaded must return NotProcessedYet")
		end
	end
	if any.premiumRead and not any.premiumChanged then out("WARN", "Premium benefits", "MembershipType read but PlayerMembershipChanged not handled") end

	-- Security / hygiene
	if ex.backdoor then out("FAIL", "Backdoor-style code (" .. ex.backdoor.count .. ")", "loadstring/getfenv/require(<id>)/InsertService: " .. table.concat(ex.backdoor, ", ")) else out("PASS", "No loadstring/require(<id>)/InsertService") end
	if ex.secret then out("FAIL", "Secret-looking literal (" .. ex.secret.count .. ")", table.concat(ex.secret, ", ")) else out("PASS", "No secret-looking literals") end
	if ex.isStudio then out("INFO", "IsStudio() branches (" .. ex.isStudio.count .. ")", "confirm no admin/debug path survives live: " .. table.concat(ex.isStudio, ", ")) end
	check(prints <= PRINT_SPAM, "print() calls (" .. prints .. ")", "WARN", "remove debug spam")
	check(any.filter, "Text filtering API", "INFO", "no FilterStringAsync/TextChatService; fine unless players can show custom text to others")

	-- Place / performance
	if env.placeId == 0 then out("INFO", "Place not published yet", "live DataStore/purchase tests need a published place") end
	if env.parts > 10000 and not env.streaming then out("WARN", "StreamingEnabled off with " .. env.parts .. " parts") else out("PASS", "Parts " .. env.parts .. ", streaming " .. tostring(env.streaming)) end
	if env.streaming then out("INFO", "Streaming radii", "min=" .. tostring(env.minR) .. " target=" .. tostring(env.targetR) .. " (Not Scriptable: verify in Workspace properties)") end
	out("INFO", "MaxPlayers", tostring(env.maxPlayers))
	out("INFO", "Unanchored parts", tostring(env.unanchored))

	-- UI
	local g = env.gui
	if g.total > 0 then
		local pct = math.floor(100 * g.offsetOnly / g.total)
		out(pct > 50 and "WARN" or "PASS", "UI offset-only sizing", pct .. "% of " .. g.total .. " GuiObjects (prefer Scale + constraints)")
		if #g.small > 0 then out("WARN", "Buttons < 44px (offset sized)", table.concat(g.small, ", ")) else out("PASS", "No small offset-sized buttons") end
	end
	if unreadable > 0 then out("INFO", "Unreadable scripts", tostring(unreadable)) end

	local lines = {}
	for _, level in ipairs({ "FAIL", "WARN", "INFO", "PASS" }) do
		for _, item in ipairs(R[level]) do table.insert(lines, level .. " " .. item) end
	end
	table.insert(lines, 1, string.format("PREFLIGHT fail=%d warn=%d info=%d pass=%d", #R.FAIL, #R.WARN, #R.INFO, #R.PASS))
	return table.concat(lines, "\n")
end

-- ===== ROBLOX COLLECTION =====
local function collect()
	local files = {}
	local roots = { "Workspace", "ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst", "StarterGui", "StarterPlayer", "StarterPack" }
	local parts, unanchored = 0, 0
	for _, rootName in ipairs(roots) do
		for _, inst in ipairs(game:GetService(rootName):GetDescendants()) do
			if inst:IsA("LuaSourceContainer") then
				local ok, src = pcall(function() return inst.Source end)
				table.insert(files, { path = inst:GetFullName(), src = ok and src or nil })
			elseif rootName == "Workspace" and inst:IsA("BasePart") then
				parts += 1
				if not inst.Anchored then unanchored += 1 end
			end
		end
	end
	local gui = { total = 0, offsetOnly = 0, small = {} }
	for _, inst in ipairs(game:GetService("StarterGui"):GetDescendants()) do
		if inst:IsA("GuiObject") then
			gui.total += 1
			local s = inst.Size
			if s.X.Scale == 0 and s.Y.Scale == 0 then
				gui.offsetOnly += 1
				if inst:IsA("GuiButton") and (s.X.Offset < 44 or s.Y.Offset < 44) and #gui.small < PER_CAT then
					table.insert(gui.small, inst:GetFullName())
				end
			end
		end
	end
	local ws = workspace
	return files, {
		placeId = game.PlaceId, streaming = ws.StreamingEnabled,
		minR = select(2, pcall(function() return ws.StreamingMinRadius end)),       -- documented Not Scriptable
		targetR = select(2, pcall(function() return ws.StreamingTargetRadius end)), -- falls back to an error string
		maxPlayers = game:GetService("Players").MaxPlayers, parts = parts, unanchored = unanchored, gui = gui,
	}
end

local files, env = collect()
return analyze(files, env)
