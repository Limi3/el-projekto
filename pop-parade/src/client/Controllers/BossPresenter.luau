--!strict
-- King Puffer presentation (client-local visuals at the arena anchor B built).
-- ALL timing comes from A's BossTelegraph/BossState events (server times); this file never
-- invents damage windows. Readability first: ground warnings + rings stay visible with Reduced
-- Effects on; only tremble/shake/extra particles are dropped.
--
-- Expected event payloads (B proposal, see CONTRACT_REQUESTS):
--   BossTelegraph { bossId, kind = "windup" | "pulse" | "knot", startsAt, duration, params? }
--   BossState     { bossId, hp, maxHp, phase = "idle" | "windup" | "pulse" | "knot" | "defeated" }

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Maid = require(script.Parent.Parent.Util.Maid)

local BossPresenter = {}
BossPresenter.__index = BossPresenter

local PINK = Color3.fromRGB(255, 120, 160)
local WARN = Color3.fromRGB(255, 70, 70)

local function mk(name: string, size: Vector3, color: Color3, parent: Instance, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

function BossPresenter.new(ctx: any)
	local self = setmetatable({ ctx = ctx, maid = Maid.new(), model = nil :: Model?, anchor = nil :: BasePart?, reduced = false, shake = true, defeated = false }, BossPresenter)
	self.maid:give(ctx.client.WorldEvent:Connect(function(ev)
		if ev.type == "BossTelegraph" then
			self:_telegraph(ev)
		elseif ev.type == "BossState" then
			self:_state(ev)
		end
	end))
	task.spawn(function()
		self:_findAnchor()
	end)
	return self
end

function BossPresenter.setFlags(self: any, reduced: boolean, shake: boolean)
	self.reduced = reduced
	self.shake = shake
end

function BossPresenter._findAnchor(self: any)
	for _ = 1, 60 do
		local world = Workspace:FindFirstChild("PopParadeWorld")
		if world then
			for _, d in world:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("PopParadeBossAnchor") == "boss.king_puffer" then
					self.anchor = d
					self:_build()
					return
				end
			end
		end
		task.wait(1)
	end
end

function BossPresenter._build(self: any)
	local anchor = self.anchor :: BasePart
	local folder = Instance.new("Model")
	folder.Name = "KingPuffer"
	folder.Parent = Workspace
	self.maid:give(folder)
	local cf = anchor.CFrame
	local body = mk("Body", Vector3.new(22, 22, 22), PINK, folder)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.08, 1)
	mesh.Parent = body
	body.CFrame = cf
	body.Reflectance = 0.05
	-- Invisible pedestal under the body while alive. Measured in Studio: the body's lowest point is
	-- level with a player's head, so players walked underneath and the camera ended up inside the
	-- boss. The pedestal keeps them at the front, where the knot (weak point) is in reach.
	for side = -1, 1, 2 do
		local eye = mk("Eye", Vector3.new(3.4, 3.4, 3.4), Color3.new(1, 1, 1), folder, Enum.PartType.Ball)
		eye.CFrame = cf * CFrame.new(side * 3.6, 2.5, 10)
		local pupil = mk("Pupil", Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(40, 30, 60), folder, Enum.PartType.Ball)
		pupil.CFrame = cf * CFrame.new(side * 3.6, 2.4, 11.4)
	end
	local mouth = mk("Mouth", Vector3.new(5, 1.2, 1), Color3.fromRGB(150, 40, 80), folder)
	mouth.CFrame = cf * CFrame.new(0, -2, 10.6)
	for i = 0, 4 do
		local a = (i / 5) * math.pi * 2
		local spike = mk("Crown", Vector3.new(1.6, 3.2, 1.6), Color3.fromRGB(255, 200, 40), folder)
		spike.Material = Enum.Material.SmoothPlastic
		spike.CFrame = cf * CFrame.new(math.cos(a) * 3.2, 12.4, math.sin(a) * 3.2)
	end
	local stage = self.ctx.Content.Layouts.RubberStage001.get()
	local wp = stage.boss.weakPointOffset
	local knot = mk("Knot", Vector3.new(3, 3, 3), Color3.fromRGB(200, 70, 110), folder)
	knot.CFrame = cf * CFrame.new(wp.x, wp.y, wp.z) * CFrame.Angles(0, 0, math.rad(45))
	local arenaTop = stage.boss.arenaCenter.y
	local bottom = cf.Position.Y - 11
	local h = math.max(2, bottom - arenaTop + 1)
	local pedestal = mk("Pedestal", Vector3.new(h, 16, 16), PINK, folder, Enum.PartType.Cylinder)
	pedestal.CFrame = CFrame.new(cf.Position.X, arenaTop + h / 2, cf.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Transparency = 1
	pedestal.CanCollide = true
	self.pedestal = pedestal
	self.model = folder
	self.body = body
	self.mesh = mesh
	self.knot = knot
	self.center = stage.boss.arenaCenter
	self.ringMax = stage.boss.params.ringMaxRadius
end

function BossPresenter._delay(self: any, startsAt: number?): number
	if type(startsAt) ~= "number" then
		return 0
	end
	return math.max(0, startsAt - self.ctx.client:serverNow())
end

function BossPresenter._groundRing(self: any, radius: number, duration: number, color: Color3, filled: boolean)
	local c = self.center
	if not c then
		return
	end
	local disk = mk("Warning", Vector3.new(0.3, 2, 2), color, Workspace, Enum.PartType.Cylinder)
	disk.Material = Enum.Material.Neon
	disk.Transparency = if filled then 0.65 else 0.4
	disk.CFrame = CFrame.new(c.x, c.y + 0.25, c.z) * CFrame.Angles(0, 0, math.rad(90))
	local tw = TweenService:Create(disk, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = if filled then 0.35 else 0.9 })
	tw.Completed:Once(function()
		disk:Destroy()
	end)
	tw:Play()
end

function BossPresenter._telegraph(self: any, ev: any)
	if not self.model then
		return
	end
	local d = self:_delay(ev.startsAt)
	local dur = math.clamp(tonumber(ev.duration) or 1, 0.1, 10)
	task.delay(d, function()
		if ev.kind == "windup" then
			-- anticipation: swell + filled ground warning that fills over the wind-up time
			if not self.reduced then
				TweenService:Create(self.mesh, TweenInfo.new(dur, Enum.EasingStyle.Sine), { Scale = Vector3.new(1.12, 1.2, 1.12) }):Play()
			end
			self:_groundRing(self.ringMax or 38, dur, WARN, true)
			self.ctx.audio:play("sfx.boss_windup", self.body.Position)
		elseif ev.kind == "pulse" then
			TweenService:Create(self.mesh, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = Vector3.new(1, 1.08, 1) }):Play()
			local speed = tonumber(ev.params and ev.params.ringSpeed) or 18
			local maxR = tonumber(ev.params and ev.params.ringMaxRadius) or self.ringMax or 38
			self:_groundRing(maxR, maxR / speed, Color3.fromRGB(255, 255, 255), false)
			self.ctx.audio:play("sfx.boss_pulse", self.body.Position)
			if self.shake and not self.reduced then
				self.ctx.camera:shake(0.35, 0.4)
			end
		elseif ev.kind == "knot" then
			local knot = self.knot :: Part
			knot.Material = Enum.Material.Neon
			knot.Color = Color3.fromRGB(255, 230, 90)
			self.ctx.toast(self.ctx.S.t("hud.boss_knot"), "gold", math.min(dur, 4))
			task.delay(dur, function()
				knot.Material = Enum.Material.SmoothPlastic
				knot.Color = Color3.fromRGB(200, 70, 110)
			end)
		end
	end)
end

function BossPresenter._state(self: any, ev: any)
	if not self.model then
		return
	end
	if ev.phase == "defeated" and not self.defeated then
		self.defeated = true
		local pos = self.body.Position
		self.ctx.effects:celebrate(pos, true)
		self.ctx.audio:play("sfx.boss_defeat", pos)
		-- the VICTORY banner is shown by WorldFeedback
		local tw = TweenService:Create(self.mesh, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = Vector3.new(0.05, 0.05, 0.05) })
		tw:Play()
		self.pedestal.CanCollide = false
		-- eyes, crown and knot pop away with the body
		for _, part in (self.model :: Model):GetChildren() do
			if part:IsA("BasePart") and part ~= self.body then
				TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
	elseif ev.phase ~= "defeated" and self.defeated then
		-- replay / new attempt: restore the boss
		self.defeated = false
		self.mesh.Scale = Vector3.new(1, 1.08, 1)
		self.pedestal.CanCollide = true
		for _, part in (self.model :: Model):GetChildren() do
			if part:IsA("BasePart") and part ~= self.pedestal then
				part.Transparency = 0
			end
		end
	end
end

function BossPresenter.destroy(self: any)
	self.maid:clean()
end

return BossPresenter
