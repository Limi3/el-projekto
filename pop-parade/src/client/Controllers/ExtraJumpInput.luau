--!strict
-- Extra (air) jump for keyboard (Space), touch (jump button) and gamepad (A) via JumpRequest.
-- Entitlement comes ONLY from A's state (owned wings, or Parkour where everyone gets one).
-- If entitled, a cosmetic local boost is applied for responsiveness and RequestExtraJump is sent
-- as an intent; the server validates budget/plausibility. The client never grants itself a jump,
-- Coins or completion, and never sends an arbitrary velocity.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Maid = require(script.Parent.Parent.Util.Maid)

local ExtraJumpInput = {}
ExtraJumpInput.__index = ExtraJumpInput

local BOOST = 46 -- upward speed for the predicted extra jump (studs/s), close to a normal jump

function ExtraJumpInput.new(ctx: any)
	local self = setmetatable({ ctx = ctx, used = false, groundedAt = 0, maid = Maid.new(), charMaid = Maid.new(), lastRequest = 0, lastSignal = 0 }, ExtraJumpInput)
	local player = Players.LocalPlayer
	local function onChar(char: Model)
		self.charMaid:clean()
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		self.used = false
		self.charMaid:give(hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
				self.used = false
				self.groundedAt = os.clock()
			end
		end))
	end
	if player.Character then
		task.spawn(onChar, player.Character)
	end
	self.maid:give(player.CharacterAdded:Connect(onChar))
	self.maid:give(UserInputService.JumpRequest:Connect(function()
		self:_onJumpRequest()
	end))
	self.maid:give(function()
		self.charMaid:clean()
	end)
	return self
end

function ExtraJumpInput.entitled(self: any): boolean
	local st = self.ctx.client.state
	if not st or self.ctx.client.status ~= "ready" then
		return false
	end
	if st.run and st.run.stunned then
		return false
	end
	if st.mode == "parkour" then
		return true -- normalised challenge kit: everyone gets one extra jump
	end
	return st.equipped ~= nil and st.equipped.Wings ~= nil
end

function ExtraJumpInput._onJumpRequest(self: any)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return
	end
	-- JumpRequest repeats every frame while the key/button is HELD, so a new press is a signal
	-- after a gap. Without this, holding Space would auto-fire the extra jump on take-off.
	local now = os.clock()
	local gap = now - self.lastSignal
	self.lastSignal = now
	-- Airborne by humanoid state, not only FloorMaterial: FloorMaterial lags several frames
	-- after take-off (measured in Studio: still "SmoothPlastic" 3 studs up), which ate quick double taps.
	local state = hum:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping or hum.FloorMaterial == Enum.Material.Air
	if not airborne then
		return -- normal ground jump: Roblox handles it
	end
	if gap < 0.09 then
		return -- still holding the first press
	end
	if self.used or os.clock() - self.groundedAt < 0.12 or os.clock() - self.lastRequest < 0.2 then
		self:_debug(if self.used then "used" else "too_soon")
		return
	end
	if not self:entitled() then
		local st = self.ctx.client.state
		self:_debug("not_entitled status=" .. tostring(self.ctx.client.status) .. " mode=" .. tostring(st and st.mode))
		return
	end
	self:_debug("fired")
	self.used = true
	self.lastRequest = os.clock()
	-- cosmetic prediction for feel (entitlement already confirmed by server state)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + BOOST, v.Z)
	self.ctx.cosmetics:flap()
	self.ctx.server:requestExtraJump(root.Position, function(r)
		if not r.ok and r.code ~= "TIMEOUT" then
			-- server said no: don't retry this airtime; A's movement validation handles correction
			self.used = true
		end
	end)
end

-- Studio-only QA breadcrumb: why the last mid-air jump press did or didn't fire.
function ExtraJumpInput._debug(_self: any, reason: string)
	if RunService:IsStudio() then
		Players.LocalPlayer:SetAttribute("PopParadeExtraJumpGate", reason)
	end
end

function ExtraJumpInput.destroy(self: any)
	self.maid:clean()
end

return ExtraJumpInput
