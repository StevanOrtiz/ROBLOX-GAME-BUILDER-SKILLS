--!strict
-- FX presets: effects as data, one builder. Idempotent (find-or-create by name) so it is safe in execute_luau.
-- Put in ReplicatedStorage/Shared/FxPresets. Sequences are {t, value} pairs; colors are {t, {r,g,b}}.
local Presets = {}

Presets.Data = {
	fire = {
		Rate = 80, Lifetime = { 0.4, 0.8 }, Speed = { 3, 6 }, Spread = { 15, 15 },
		Size = { { 0, 0.5 }, { 0.3, 1.5 }, { 1, 0 } },
		Color = { { 0, { 255, 220, 50 } }, { 0.4, { 255, 100, 0 } }, { 1, { 100, 20, 0 } } },
		Transparency = { { 0, 0.3 }, { 1, 1 } },
		LightEmission = 1, Acceleration = { 0, 4, 0 },
		Texture = "rbxasset://textures/particles/fire_main.dds",
	},
	smoke = {
		Rate = 30, Lifetime = { 2, 4 }, Speed = { 1, 3 }, Spread = { 30, 30 },
		Size = { { 0, 1 }, { 1, 5 } },
		Color = { { 0, { 120, 120, 120 } }, { 1, { 120, 120, 120 } } },
		Transparency = { { 0, 0.5 }, { 1, 1 } },
		RotSpeed = { -30, 30 }, Acceleration = { 0, 2, 0 }, LightInfluence = 1,
	},
	sparkle = {
		Rate = 40, Lifetime = { 0.5, 1.2 }, Speed = { 2, 5 }, Spread = { 180, 180 },
		Size = { { 0, 0.3 }, { 0.5, 0.6 }, { 1, 0 } },
		Color = { { 0, { 200, 200, 255 } }, { 1, { 100, 100, 255 } } },
		Transparency = { { 0, 0 }, { 1, 1 } },
		LightEmission = 1,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
	},
	rain = { -- client only, emitter part follows the camera
		Rate = 300, Lifetime = { 0.8, 1.2 }, Speed = { 40, 60 }, Spread = { 5, 5 },
		Size = { { 0, 0.05 }, { 1, 0.05 } },
		Color = { { 0, { 180, 200, 220 } }, { 1, { 180, 200, 220 } } },
		Transparency = { { 0, 0.4 }, { 1, 0.4 } },
		Acceleration = { 0, -80, 0 }, Drag = 0, Orientation = "VelocityParallel",
	},
	snow = {
		Rate = 100, Lifetime = { 4, 7 }, Speed = { 1, 3 }, Spread = { 60, 60 },
		Size = { { 0, 0.1 }, { 1, 0.15 } },
		Color = { { 0, { 255, 255, 255 } }, { 1, { 255, 255, 255 } } },
		Transparency = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } },
		Acceleration = { 0, -2, 0 }, RotSpeed = { -60, 60 }, Drag = 3,
	},
	aura = {
		Rate = 25, Lifetime = { 1, 2 }, Speed = { 0.5, 1.5 }, Spread = { 180, 180 },
		Size = { { 0, 0 }, { 0.3, 0.8 }, { 1, 0 } },
		Color = { { 0, { 100, 0, 255 } }, { 1, { 200, 50, 255 } } },
		Transparency = { { 0, 1 }, { 0.2, 0.2 }, { 1, 1 } },
		LightEmission = 1, RotSpeed = { -90, 90 }, Drag = 5,
	},
}

local function ns(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function cs(points: { any }): ColorSequence
	local keys = {}
	for _, p in points do
		local c = p[2]
		table.insert(keys, ColorSequenceKeypoint.new(p[1], Color3.fromRGB(c[1], c[2], c[3])))
	end
	return ColorSequence.new(keys)
end

-- Build (or update) the emitter named "Fx_<name>" under parent. Overrides replace preset fields.
function Presets.Build(name: string, parent: Instance, overrides: { [string]: any }?): ParticleEmitter
	local base = Presets.Data[name]
	assert(base, `[Fx] unknown preset {name}`)
	local p: { [string]: any } = table.clone(base)
	if overrides then
		for k, v in overrides do p[k] = v end
	end

	local emitterName = "Fx_" .. name
	local existing = parent:FindFirstChild(emitterName)
	local e: ParticleEmitter
	if existing and existing:IsA("ParticleEmitter") then
		e = existing
	else
		if existing ~= nil then (existing :: Instance):Destroy() end
		e = Instance.new("ParticleEmitter")
		e.Name = emitterName
	end

	e.Rate = p.Rate
	e.Lifetime = NumberRange.new(p.Lifetime[1], p.Lifetime[2])
	e.Speed = NumberRange.new(p.Speed[1], p.Speed[2])
	e.SpreadAngle = Vector2.new(p.Spread[1], p.Spread[2])
	e.Size = ns(p.Size)
	e.Color = cs(p.Color)
	e.Transparency = ns(p.Transparency)
	e.LightEmission = p.LightEmission or 0
	e.LightInfluence = p.LightInfluence or 0
	e.Drag = p.Drag or 0
	if p.Acceleration then e.Acceleration = Vector3.new(p.Acceleration[1], p.Acceleration[2], p.Acceleration[3]) end
	if p.RotSpeed then e.RotSpeed = NumberRange.new(p.RotSpeed[1], p.RotSpeed[2]) end
	if p.Orientation then e.Orientation = (Enum.ParticleOrientation :: any)[p.Orientation] end
	if p.Texture then e.Texture = p.Texture end
	e.Parent = parent
	return e
end

return Presets
-- Use:  Presets.Build("fire", torchAttachment)
--       Presets.Build("sparkle", part, { Rate = 0 })  then  emitter:Emit(20)  for a burst
