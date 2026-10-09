-- Paste at the top of the execute_luau build script. Idempotent: find-or-create by name.
local CS = game:GetService("CollectionService")

local function make(class, name, parent, props)
	local inst = parent:FindFirstChild(name)
	if inst and not inst:IsA(class) then inst:Destroy(); inst = nil end
	if not inst then inst = Instance.new(class); inst.Name = name; inst.Parent = parent end
	for k, v in pairs(props or {}) do inst[k] = v end
	return inst
end

-- role tags let a restyle pass retarget by role: CS:GetTagged("UI_Primary")
local function role(inst, r) CS:AddTag(inst, "UI_" .. r); return inst end

-- Decorations, named by type
local function corner(p, radius) return make("UICorner", "Corner", p, {CornerRadius = UDim.new(0, radius or 8)}) end
local function stroke(p, color, t) return make("UIStroke", "Stroke", p, {Color = color, Thickness = t or 1}) end
local function pad(p, px) local u = UDim.new(0, px or 8)
	return make("UIPadding", "Padding", p, {PaddingTop=u, PaddingBottom=u, PaddingLeft=u, PaddingRight=u}) end
local function list(p, gap, dir) return make("UIListLayout", "Layout", p,
	{Padding = UDim.new(0, gap or 6), FillDirection = dir or Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder}) end

-- Name contract: every path the controller needs. Verify at the end.
local function verify(root, paths)
	local missing = {}
	for _, path in ipairs(paths) do
		local cur = root
		for seg in string.gmatch(path, "[^%.]+") do cur = cur and cur:FindFirstChild(seg) end
		if not cur then table.insert(missing, path) end
	end
	return missing
end

-- Usage sketch:
-- local gui = make("ScreenGui","ShopGui",game.StarterGui,{ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
-- local main = make("Frame","Main",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.5,.6),Visible=false})
-- ... build ...
-- return {missing = verify(gui, {"Main.Header.CloseButton","Main.Body.ItemList","Templates.ItemTemplate"})}
