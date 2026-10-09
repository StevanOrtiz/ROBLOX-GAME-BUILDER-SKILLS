--!strict
-- HitEffect (client only). Server validates the hit and fires a remote; the client calls Play.
-- Put in StarterPlayerScripts/Fx next to CameraFx.
local TweenService = game:GetService("TweenService")
local CameraFx = require(script.Parent.CameraFx)

local HitEffect = {}

local DEFAULT: { [string]: any } = {
	flashColor = Color3.new(1, 1, 1),
	flashFade = 0.25,
	burstCount = 20,
	soundId = "rbxassetid://0", -- replace with an asset the experience may use
	soundVolume = 0.8,
	pitchVariation = 0.15,
	shake = true,
	shakeIntensity = 0.4,
	shakeDuration = 0.2,
}

local running: { [Highlight]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function flash(target: Instance, cfg: { [string]: any })
	local existing = target:FindFirstChild("HitFlash")
	local hl: Highlight
	if existing and existing:IsA("Highlight") then
		hl = existing
	else
		hl = Instance.new("Highlight")
		hl.Name = "HitFlash"
		hl.OutlineTransparency = 1
		hl.FillTransparency = 1
		hl.Adornee = target
		hl.Parent = target
	end
	local previous = running[hl]
	if previous then previous:Cancel() end -- re-hit: restart, nothing to "restore" so no stuck color

	hl.FillColor = cfg.flashColor
	hl.FillTransparency = 0.2
	local tween = TweenService:Create(hl, TweenInfo.new(cfg.flashFade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 })
	running[hl] = tween
	tween:Play()
end

local function burst(part: BasePart, cfg: { [string]: any })
	local emitter = part:FindFirstChild("HitBurst")
	if not (emitter and emitter:IsA("ParticleEmitter")) then
		local e = Instance.new("ParticleEmitter")
		e.Name = "HitBurst"
		e.Rate = 0 -- manual emission only
		e.Lifetime = NumberRange.new(0.2, 0.5)
		e.Speed = NumberRange.new(8, 15)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 200, 50))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.LightEmission = 1
		e.Drag = 5
		e.RotSpeed = NumberRange.new(-180, 180)
		e.Parent = part
		emitter = e
	end
	(emitter :: ParticleEmitter):Emit(cfg.burstCount)
end

local function sound(part: BasePart, cfg: { [string]: any })
	local s = Instance.new("Sound")
	s.SoundId = cfg.soundId
	s.Volume = cfg.soundVolume
	s.PlaybackSpeed = 1 + (math.random() - 0.5) * 2 * cfg.pitchVariation
	s.RollOffMinDistance = 5
	s.RollOffMaxDistance = 80
	s.Parent = part
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(5, function() -- failed loads never fire Ended
		if s.Parent then s:Destroy() end
	end)
end

-- part: where it hit. opts overrides DEFAULT. Pass shake = false when the local player isn't involved.
function HitEffect.Play(part: BasePart, opts: { [string]: any }?)
	local cfg = table.clone(DEFAULT)
	if opts then
		for k, v in opts do cfg[k] = v end
	end
	flash(part:FindFirstAncestorOfClass("Model") or part, cfg)
	burst(part, cfg)
	sound(part, cfg)
	if cfg.shake then CameraFx.Shake(cfg.shakeIntensity, cfg.shakeDuration) end
end

return HitEffect
-- Client usage:
--   HitConfirmed.OnClientEvent:Connect(function(part: BasePart, isCrit: boolean, involvesMe: boolean)
--     HitEffect.Play(part, { shake = involvesMe, burstCount = if isCrit then 40 else 20,
--                            flashColor = if isCrit then Color3.fromRGB(255, 50, 50) else nil })
--   end)
