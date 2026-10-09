--!strict
-- CameraFx (client only). Put in StarterPlayerScripts/Fx.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraFx = {}
CameraFx.Enabled = true   -- bind to a "Reduce camera shake" setting
CameraFx.BaseFov = 70

local BIND = "CameraFxShake"
local shaking = false
local intensity, duration, elapsed = 0, 0, 0

local function humanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function stopShake()
	if shaking then
		RunService:UnbindFromRenderStep(BIND)
		shaking = false
	end
	local h = humanoid()
	if h then h.CameraOffset = Vector3.zero end
end

-- Shake through Humanoid.CameraOffset: no fighting the camera script, no drift.
function CameraFx.Shake(newIntensity: number, newDuration: number)
	if not CameraFx.Enabled or newDuration <= 0 then return end
	if shaking then
		local remaining = intensity * (1 - elapsed / duration)
		if newIntensity <= remaining then return end -- keep the stronger shake
	end
	intensity, duration, elapsed = newIntensity, newDuration, 0
	if shaking then return end
	shaking = true
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		elapsed += dt
		local h = humanoid()
		if elapsed >= duration or not h then
			stopShake()
			return
		end
		local k = intensity * (1 - elapsed / duration)
		h.CameraOffset = Vector3.new((math.random() - 0.5) * 2 * k, (math.random() - 0.5) * 2 * k, 0)
	end)
end

function CameraFx.Zoom(fov: number, time: number): Tween
	local tween = TweenService:Create(
		workspace.CurrentCamera,
		TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = fov }
	)
	tween:Play()
	return tween
end

function CameraFx.ResetZoom(time: number): Tween
	return CameraFx.Zoom(CameraFx.BaseFov, time)
end

export type Waypoint = { cframe: CFrame, duration: number, style: Enum.EasingStyle?, hold: number? }

local playing = false
local skipRequested = false
local currentTween: Tween? = nil

function CameraFx.Skip()
	skipRequested = true
	if currentTween then currentTween:Cancel() end
end

-- Yields until finished or skipped. Always restores the camera type, even on error.
function CameraFx.Cutscene(waypoints: { Waypoint })
	if playing then return end
	playing, skipRequested = true, false
	local camera = workspace.CurrentCamera
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local ok, err = pcall(function()
		for _, wp in waypoints do
			if skipRequested then break end
			local info = TweenInfo.new(wp.duration, wp.style or Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			local tween = TweenService:Create(camera, info, { CFrame = wp.cframe })
			currentTween = tween
			tween:Play()
			tween.Completed:Wait()
			currentTween = nil
			if wp.hold and wp.hold > 0 and not skipRequested then task.wait(wp.hold) end
		end
	end)

	camera.CameraType = previousType
	playing = false
	if not ok then warn(`[CameraFx] cutscene failed: {err}`) end
end

return CameraFx
-- Waypoint example (use lookAt for a full CFrame, don't multiply it by another position):
--   CameraFx.Cutscene({
--     { cframe = CFrame.lookAt(Vector3.new(20, 10, 20), Vector3.zero), duration = 3, hold = 1 },
--   })
