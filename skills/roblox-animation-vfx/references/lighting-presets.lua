--!strict
-- Run in execute_luau (edit mode) to set scene mood once. Idempotent: reuses one effect per class.
-- Change PRESET, run, done. The result persists in the place.
local PRESET = "Night"

local Lighting = game:GetService("Lighting")

local PRESETS: { [string]: { [string]: { [string]: any } } } = {
	Day = {
		Lighting = { ClockTime = 14, Brightness = 2, Ambient = Color3.fromRGB(140, 140, 140), OutdoorAmbient = Color3.fromRGB(130, 130, 130), FogEnd = 100000 },
		Atmosphere = { Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(200, 210, 230), Decay = Color3.fromRGB(120, 140, 170), Glare = 0.2, Haze = 1.5 },
		ColorCorrectionEffect = { Brightness = 0.05, Contrast = 0.1, Saturation = 0.15, TintColor = Color3.new(1, 0.95, 0.9) },
		BloomEffect = { Intensity = 0.4, Size = 24, Threshold = 1.2 },
		SunRaysEffect = { Intensity = 0.15, Spread = 0.8 },
	},
	Night = {
		Lighting = { ClockTime = 0, Brightness = 0.5, Ambient = Color3.fromRGB(20, 20, 40), OutdoorAmbient = Color3.fromRGB(10, 10, 30), FogEnd = 200, FogColor = Color3.fromRGB(15, 15, 30) },
		Atmosphere = { Density = 0.4, Offset = 0, Color = Color3.fromRGB(40, 50, 90), Decay = Color3.fromRGB(10, 10, 30), Glare = 0, Haze = 2 },
		ColorCorrectionEffect = { Brightness = 0, Contrast = 0.15, Saturation = -0.1, TintColor = Color3.fromRGB(200, 210, 255) },
		BloomEffect = { Intensity = 0.8, Size = 24, Threshold = 1 },
	},
}

local function apply(inst: any, props: { [string]: any })
	for k, v in props do inst[k] = v end
end

local function ensure(className: string): any
	local found = Lighting:FindFirstChildOfClass(className :: any)
	if found then return found end
	local created = Instance.new(className :: any)
	created.Parent = Lighting
	return created
end

local preset = PRESETS[PRESET]
assert(preset, "unknown preset " .. PRESET)
apply(Lighting, preset.Lighting)
local set = { "Lighting" }
for className, props in preset do
	if className ~= "Lighting" then
		apply(ensure(className), props)
		table.insert(set, className)
	end
end
return PRESET .. ": " .. table.concat(set, ", ")
