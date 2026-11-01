--!strict
-- Equipped cosmetics on avatars (needle skin, trail, wings) for the local player AND everyone
-- nearby, built procedurally from VisualCatalog descriptors. Premium looks differ only in
-- presentation (extra particles/animation), never stats. Respects Reduced Effects.
--
-- Local player: equipped IDs from A's ClientState.
-- Other players: read from Player attributes PopParade_NeedleSkin / _Trail / _Wings that A sets
-- (requested in docs/b/CONTRACT_REQUESTS.md). Missing attributes = default needle, nothing else.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Maid = require(script.Parent.Parent.Util.Maid)

local CosmeticsController = {}
CosmeticsController.__index = CosmeticsController

local SLOTS = { "NeedleSkin", "Trail", "Wings" }

local function c3(rgb: any): Color3
	return Color3.new(rgb.r, rgb.g, rgb.b)
end

local function seq(colors: { any }): ColorSequence
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new(if #colors == 1 then 0 else (i - 1) / (#colors - 1), c3(c)))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
	end
	return ColorSequence.new(keys)
end

local function part(name: string, size: Vector3, color: Color3, parent: Instance, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart, c0: CFrame): Weld
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = c0
	w.Parent = b
	return w
end

type Rig = { maid: any, model: Model?, needleWeld: Weld?, wings: { Part }, equipped: { [string]: string? }, spin: number }

function CosmeticsController.new(ctx: any)
	local self = setmetatable({ ctx = ctx, rigs = {} :: { [Player]: Rig }, reduced = false, maid = Maid.new(), previewUntil = 0, previewSlot = nil :: string?, previewId = nil :: string? }, CosmeticsController)
	local function track(plr: Player)
		local function rebuild()
			self:_rebuild(plr)
		end
		self.maid:give(plr.CharacterAdded:Connect(function()
			task.defer(rebuild)
		end))
		for _, slot in SLOTS do
			self.maid:give(plr:GetAttributeChangedSignal("PopParade_" .. slot):Connect(rebuild))
		end
		if plr.Character then
			task.defer(rebuild)
		end
	end
	for _, plr in Players:GetPlayers() do
		track(plr)
	end
	self.maid:give(Players.PlayerAdded:Connect(track))
	self.maid:give(Players.PlayerRemoving:Connect(function(plr)
		local rig = self.rigs[plr]
		if rig then
			rig.maid:clean()
			self.rigs[plr] = nil
		end
	end))
	self.maid:give(ctx.client.StateChanged:Connect(function(state, prev)
		local a: any = state and state.equipped or {}
		local b: any = prev and prev.equipped or {}
		if a.NeedleSkin ~= b.NeedleSkin or a.Trail ~= b.Trail or a.Wings ~= b.Wings then
			self:_rebuild(Players.LocalPlayer)
		end
	end))
	self.maid:give(RunService.Heartbeat:Connect(function(dt)
		self:_spin(dt)
		if self.previewSlot and os.clock() > self.previewUntil then
			self.previewSlot = nil
			self.previewId = nil
			self:_rebuild(Players.LocalPlayer)
		end
	end))
	return self
end

function CosmeticsController.setReduced(self: any, v: boolean)
	if self.reduced ~= v then
		self.reduced = v
		for plr in self.rigs do
			self:_rebuild(plr)
		end
	end
end

function CosmeticsController._equippedFor(self: any, plr: Player): { [string]: string? }
	local out: { [string]: string? } = {}
	if plr == Players.LocalPlayer then
		local st = self.ctx.client.state
		local eq = st and st.equipped or {}
		for _, slot in SLOTS do
			out[slot] = eq[slot]
		end
		if self.previewSlot then
			out[self.previewSlot] = self.previewId
		end
	else
		for _, slot in SLOTS do
			local v = plr:GetAttribute("PopParade_" .. slot)
			out[slot] = if type(v) == "string" then v else nil
		end
	end
	out.NeedleSkin = out.NeedleSkin or "skin.default"
	return out
end

function CosmeticsController._rebuild(self: any, plr: Player)
	local old = self.rigs[plr]
	if old then
		old.maid:clean()
	end
	local char = plr.Character
	if not char then
		self.rigs[plr] = nil
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not root or not hand or not torso then
		return
	end
	local Catalog = self.ctx.Content.VisualCatalog
	local maid = Maid.new()
	local model = Instance.new("Model")
	model.Name = "PopParadeCosmetics"
	model.Parent = char
	maid:give(model)
	local rig: Rig = { maid = maid, model = model, needleWeld = nil, wings = {}, equipped = self:_equippedFor(plr), spin = 0 }

	-- Needle (held in the right hand, tip forward)
	local nd = Catalog.get(rig.equipped.NeedleSkin :: string)
	local colA = c3(nd.colors[1])
	local colB = c3(nd.colors[2] or nd.colors[1])
	local shaft = part("NeedleShaft", Vector3.new(0.18, 0.18, 2.6), colA, model)
	if nd.style.material then
		shaft.Material = (Enum.Material :: any)[nd.style.material] or Enum.Material.SmoothPlastic
	end
	rig.needleWeld = weld(hand, shaft, CFrame.new(0, -0.4, -1.2))
	local tip = part("NeedleTip", Vector3.new(0.12, 0.12, 0.6), Color3.new(0.9, 0.92, 0.95), model)
	tip.Material = Enum.Material.Metal
	weld(shaft, tip, CFrame.new(0, 0, -1.55))
	local grip = part("NeedleGrip", Vector3.new(0.5, 0.5, 0.5), colB, model, Enum.PartType.Ball)
	weld(shaft, grip, CFrame.new(0, 0, 1.3))
	if nd.style.shape == "crown" then
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			local gem = part("Gem", Vector3.new(0.18, 0.18, 0.18), c3(nd.colors[(i % #nd.colors) + 1]), model, Enum.PartType.Ball)
			gem.Material = Enum.Material.Neon
			weld(shaft, gem, CFrame.new(math.cos(a) * 0.32, math.sin(a) * 0.32, 1.3))
		end
	elseif nd.style.shape == "founder" then
		local star = part("Star", Vector3.new(0.5, 0.5, 0.12), Color3.fromRGB(255, 200, 60), model)
		weld(shaft, star, CFrame.new(0, 0, 1.7) * CFrame.Angles(0, 0, math.rad(45)))
		local star2 = part("Star2", Vector3.new(0.5, 0.5, 0.12), Color3.fromRGB(255, 200, 60), model)
		weld(shaft, star2, CFrame.new(0, 0, 1.7))
		local pennant = part("Pennant", Vector3.new(0.05, 0.4, 0.7), Color3.fromRGB(30, 40, 90), model)
		weld(shaft, pennant, CFrame.new(0, 0.3, 0.6))
	elseif nd.style.glow and not self.reduced then
		shaft.Material = Enum.Material.Neon
	end

	-- Trail
	local trailId = rig.equipped.Trail
	if trailId then
		local td = Catalog.get(trailId)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.9, 0.4)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.9, 0.4)
		a1.Parent = root
		maid:give(a0)
		maid:give(a1)
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = seq(td.colors)
		trail.Lifetime = (td.style.lifetime or 0.5) * (if self.reduced then 0.6 else 1)
		trail.WidthScale = NumberSequence.new(td.style.width or 1, 0)
		trail.Transparency = NumberSequence.new(0.15, 1)
		trail.LightEmission = td.style.lightEmission or 0.2
		trail.FaceCamera = true
		trail.Parent = root
		maid:give(trail)
		if td.style.particles and not self.reduced then
			local pe = Instance.new("ParticleEmitter")
			pe.Rate = td.style.sparkleRate or 10
			pe.Lifetime = NumberRange.new(0.4, 0.8)
			pe.Speed = NumberRange.new(0.5, 2)
			pe.Size = NumberSequence.new(0.25, 0)
			pe.Color = seq(td.colors)
			pe.LightEmission = 0.6
			pe.Parent = a1
			maid:give(pe)
		end
	end

	-- Wings (on the back)
	local wingsId = rig.equipped.Wings
	if wingsId then
		local wd = Catalog.get(wingsId)
		for side = -1, 1, 2 do
			local w = part("Wing", Vector3.new(0.15, 1.8, 1.4), c3(wd.colors[1]), model)
			w.Transparency = 0.1
			weld(torso, w, CFrame.new(side * 0.55, 0.3, 0.6) * CFrame.Angles(0, math.rad(side * -35), math.rad(side * 20)))
			if wd.style.gradient and #wd.colors > 1 then
				local inner = part("WingTip", Vector3.new(0.17, 0.8, 0.7), c3(wd.colors[2]), model)
				weld(w, inner, CFrame.new(0, 0.5, 0.3))
			end
			if wd.style.sparkles and not self.reduced then
				local pe = Instance.new("ParticleEmitter")
				pe.Rate = 4
				pe.Lifetime = NumberRange.new(0.6, 1)
				pe.Speed = NumberRange.new(0.2, 0.8)
				pe.Size = NumberSequence.new(0.2, 0)
				pe.Color = seq(wd.colors)
				pe.LightEmission = 0.7
				pe.Parent = w
			end
			table.insert(rig.wings, w)
		end
	end
	self.rigs[plr] = rig
end

function CosmeticsController._spin(self: any, dt: number)
	if self.reduced then
		return
	end
	for _, rig in self.rigs do
		local w = rig.needleWeld
		if w and w.Parent then
			rig.spin = (rig.spin + dt * 360 * 0.6) % 360
			w.C1 = CFrame.Angles(0, 0, math.rad(rig.spin)) -- visual roll only; never affects attack rate
		end
	end
end

-- Readable auto-needle motion: quick jab toward the target on a server-confirmed hit.
function CosmeticsController.thrust(self: any, _slotId: string)
	local rig = self.rigs[Players.LocalPlayer]
	local w = rig and rig.needleWeld
	if not w or self.reduced then
		return
	end
	local base = CFrame.new(0, -0.4, -1.2)
	w.C0 = base * CFrame.new(0, 0, -0.9)
	TweenService:Create(w, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base }):Play()
end

function CosmeticsController.flap(self: any, plr: Player?)
	local rig = self.rigs[plr or Players.LocalPlayer]
	if not rig or self.reduced then
		return
	end
	for _, w in rig.wings do
		local wd = w:FindFirstChildOfClass("Weld")
		if wd then
			local c0 = wd.C0
			wd.C0 = c0 * CFrame.Angles(0, 0, math.rad(25))
			TweenService:Create(wd, TweenInfo.new(0.25, Enum.EasingStyle.Back), { C0 = c0 }):Play()
		end
	end
end

-- Local-only try-on from the inventory (6 seconds). Purely visual; other players don't see it.
function CosmeticsController.preview(self: any, slot: string, itemId: string)
	self.previewSlot = slot
	self.previewId = itemId
	self.previewUntil = os.clock() + 6
	self:_rebuild(Players.LocalPlayer)
end

function CosmeticsController.destroy(self: any)
	for _, rig in self.rigs do
		rig.maid:clean()
	end
	table.clear(self.rigs)
	self.maid:clean()
end

return CosmeticsController
