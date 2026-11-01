--!strict
-- Gentle camera shake for big moments. Disabled when the player turns Screen Shake off or
-- enables Reduced Motion.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraShake = {}
CameraShake.__index = CameraShake

function CameraShake.new()
	local self = setmetatable({ enabled = true, untilT = 0, strength = 0, bound = false }, CameraShake)
	return self
end

function CameraShake.setEnabled(self: any, on: boolean)
	self.enabled = on
end

function CameraShake.shake(self: any, strength: number, duration: number)
	if not self.enabled then
		return
	end
	self.strength = math.max(self.strength, strength)
	self.untilT = math.max(self.untilT, os.clock() + duration)
	if self.bound then
		return
	end
	self.bound = true
	RunService:BindToRenderStep("PopParadeShake", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = Workspace.CurrentCamera
		local left = self.untilT - os.clock()
		if left <= 0 or not cam then
			RunService:UnbindFromRenderStep("PopParadeShake")
			self.bound = false
			self.strength = 0
			return
		end
		local s = self.strength * math.min(1, left * 3)
		cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * s), math.rad((math.random() - 0.5) * s), 0)
	end)
end

return CameraShake
