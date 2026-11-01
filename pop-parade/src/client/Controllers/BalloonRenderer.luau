--!strict
-- Renders the LOCAL player's balloons from server-approved state.
--   * Definitions (position, colour step, material) come from shared public layouts by stable ID;
--     whether a balloon exists/is active comes only from A's BalloonState for this player, so
--     another player's pops can never remove this player's balloons or progress.
--   * Cosmetic bobbing / hue drift only move the VISUAL; the logical position never changes.
--   * Pop/Inflate are applied once per generation (GameClient dedupes); snapshots rebuild views.
--   * Views are pooled, distance-culled and cleaned up with the controller.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Pool = require(script.Parent.Parent.Util.Pool)
local Maid = require(script.Parent.Parent.Util.Maid)

local BalloonRenderer = {}
BalloonRenderer.__index = BalloonRenderer

local RENDER_DISTANCE = 240
local ANIMATE_DISTANCE = 90
local MAX_VIEWS = 260
local BODY = Vector3.new(3.4, 4, 3.4)

type View = { model: Model, body: Part, mesh: SpecialMesh, knot: Part, tether: Part, slotId: string?, baseColor: Color3 }

function BalloonRenderer.new(ctx: any)
	local Content = ctx.Content
	local self = setmetatable({
		ctx = ctx,
		Materials = Content.Materials,
		Palette = Content.Palette,
		defs = {} :: { [string]: any },
		views = {} :: { [string]: View },
		reduced = false,
		maid = Maid.new(),
		highlight = nil :: Highlight?,
		target = nil :: string?,
	}, BalloonRenderer)
	for _, b in Content.Layouts.Hub.get().practice do
		self.defs[b.id] = b
	end
	for _, b in Content.Layouts.RubberStage001.get().balloons do
		self.defs[b.id] = b
	end
	for _, b in Content.Layouts.Parkour001.get().sideBalloons do
		self.defs[b.id] = b
	end

	local folder = Instance.new("Folder")
	folder.Name = "PopParadeBalloons"
	folder.Parent = Workspace
	self.folder = folder
	self.maid:give(folder)

	self.pool = Pool.new(function(): View
		local model = Instance.new("Model")
		model.Name = "Balloon"
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		body.CastShadow = false
		body.Size = BODY
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
		body.Parent = model
		local knot = Instance.new("Part")
		knot.Name = "Knot"
		knot.Anchored = true
		knot.CanCollide = false
		knot.CanQuery = false
		knot.CanTouch = false
		knot.CastShadow = false
		knot.Size = Vector3.new(0.6, 0.6, 0.6)
		knot.Parent = model
		local tether = Instance.new("Part")
		tether.Name = "String"
		tether.Anchored = true
		tether.CanCollide = false
		tether.CanQuery = false
		tether.CanTouch = false
		tether.CastShadow = false
		tether.Size = Vector3.new(0.08, 2.2, 0.08)
		tether.Color = Color3.new(1, 1, 1)
		tether.Material = Enum.Material.SmoothPlastic
		tether.Parent = model
		model.PrimaryPart = body
		return { model = model, body = body, mesh = mesh, knot = knot, tether = tether, slotId = nil, baseColor = Color3.new(1, 1, 1) }
	end, function(v: View)
		v.model.Parent = nil
		v.slotId = nil
	end, MAX_VIEWS, function(v: View)
		v.model:Destroy()
	end)
	self.maid:give(function()
		self.pool:destroy()
	end)

	local client = ctx.client
	self.maid:give(client.WorldSnapshot:Connect(function()
		self:rebuild()
	end))
	self.maid:give(client.BalloonState:Connect(function(b)
		self:_applyState(b)
	end))
	self.maid:give(client.WorldEvent:Connect(function(ev)
		self:_onEvent(ev)
	end))

	local t0 = os.clock()
	local acc, cullAcc = 0, 0
	self.maid:give(RunService.Heartbeat:Connect(function(dt)
		acc += dt
		cullAcc += dt
		if cullAcc >= 0.5 then
			cullAcc = 0
			self:_cull()
		end
		if acc >= 1 / 30 then
			acc = 0
			self:_animate(os.clock() - t0)
			self:_updateTarget()
		end
	end))
	return self
end

function BalloonRenderer.setReduced(self: any, v: boolean)
	self.reduced = v
end

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

function BalloonRenderer._place(self: any, v: View, def: any, offsetY: number)
	local p = def.pos
	local cf = CFrame.new(p.x, p.y + offsetY, p.z)
	v.body.CFrame = cf
	v.knot.CFrame = cf * CFrame.new(0, -BODY.Y / 2 - 0.15, 0) * CFrame.Angles(0, 0, math.rad(45))
	v.tether.CFrame = cf * CFrame.new(0, -BODY.Y / 2 - 1.3, 0)
end

function BalloonRenderer._styleView(self: any, v: View, def: any, stepOverride: number?)
	local tr = self.Materials.treatment(def.material, stepOverride or def.colorStep)
	local col = Color3.new(tr.body.r, tr.body.g, tr.body.b)
	v.baseColor = col
	v.body.Color = col
	v.body.Material = (Enum.Material :: any)[tr.robloxMaterial] or Enum.Material.SmoothPlastic
	v.body.Transparency = tr.transparency
	v.body.Reflectance = tr.reflectance
	local f = tr.frame
	v.knot.Color = if f then Color3.new(f.r, f.g, f.b) else col
	if not def.required then
		-- optional/bonus balloons read differently: gold knot + slightly smaller body
		v.knot.Color = Color3.fromRGB(255, 200, 40)
	end
end

function BalloonRenderer._viewFor(self: any, slotId: string): View?
	local v = self.views[slotId]
	if v then
		return v
	end
	local def = self.defs[slotId]
	if not def then
		return nil -- unknown to B's content (e.g. A-side test slot): never invent visuals
	end
	local p = def.pos
	if (Vector3.new(p.x, p.y, p.z) - camPos()).Magnitude > RENDER_DISTANCE then
		return nil
	end
	local nv = self.pool:acquire()
	if not nv then
		return nil
	end
	nv.slotId = slotId
	nv.model.Name = slotId
	self:_styleView(nv, def, nil)
	nv.mesh.Scale = if def.required then Vector3.one else Vector3.one * 0.85
	self:_place(nv, def, 0)
	nv.model.Parent = self.folder
	self.views[slotId] = nv
	return nv
end

function BalloonRenderer._release(self: any, slotId: string)
	local v = self.views[slotId]
	if v then
		self.views[slotId] = nil
		self.pool:release(v)
	end
end

function BalloonRenderer.rebuild(self: any)
	for id in self.views do
		self:_release(id)
	end
	for id, b in self.ctx.client.balloonStates do
		if b.state == "Active" then
			self:_viewFor(id)
		end
	end
end

function BalloonRenderer._applyState(self: any, b: any)
	if b.state == "Active" then
		self:_viewFor(b.slotId)
	else
		-- Popped/Respawning: hide; the Pop event (if any) already played the burst
		self:_release(b.slotId)
	end
end

function BalloonRenderer._onEvent(self: any, ev: any)
	local ctx = self.ctx
	local localId = Players.LocalPlayer.UserId
	if ev.type == "Damage" then
		local v = self.views[ev.slotId]
		if v and not self.reduced then
			v.mesh.Scale = Vector3.new(1.18, 0.82, 1.18)
			TweenService:Create(v.mesh, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = Vector3.one }):Play()
		end
		if ev.sourceUserId == localId and type(ev.amount) == "number" then
			ctx.damageNumbers:show(ev.amount)
			ctx.cosmetics:thrust(ev.slotId)
		end
	elseif ev.type == "Pop" then
		local def = self.defs[ev.slotId]
		local v = self.views[ev.slotId]
		if def then
			local pos = Vector3.new(def.pos.x, def.pos.y, def.pos.z)
			local mine = ev.sourceUserId == nil or ev.sourceUserId == localId
			local state = ctx.client.state
			local fx = if mine and state and state.equipped then state.equipped.PopEffect else nil
			local snd = if mine and state and state.equipped and state.equipped.Sound then state.equipped.Sound else "sound.classic_pop"
			ctx.effects:pop(pos, if v then v.baseColor else Color3.new(1, 1, 1), fx)
			ctx.audio:play(snd, pos)
		end
		self:_release(ev.slotId)
	elseif ev.type == "Inflate" then
		local v = self:_viewFor(ev.slotId)
		local def = self.defs[ev.slotId]
		if v and def then
			if not self.reduced then
				local target = if def.required then Vector3.one else Vector3.one * 0.85
				v.mesh.Scale = target * 0.15
				TweenService:Create(v.mesh, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
			end
			ctx.audio:play("sfx.inflate", Vector3.new(def.pos.x, def.pos.y, def.pos.z))
		end
	end
end

function BalloonRenderer._cull(self: any)
	local cam = camPos()
	-- release far views
	for id, v in self.views do
		if (v.body.Position - cam).Magnitude > RENDER_DISTANCE + 20 then
			self:_release(id)
		end
	end
	-- create near views for active balloons we know about
	for id, b in self.ctx.client.balloonStates do
		if b.state == "Active" and not self.views[id] then
			self:_viewFor(id)
		end
	end
end

function BalloonRenderer._animate(self: any, t: number)
	if self.reduced then
		return
	end
	local cam = camPos()
	local hueTick = math.floor(t * 4) -- hue drift updates 4x/s, not every frame
	local doHue = hueTick ~= self._lastHueTick
	self._lastHueTick = hueTick
	for id, v in self.views do
		local def = self.defs[id]
		if def and (v.body.Position - cam).Magnitude < ANIMATE_DISTANCE then
			local phase = (def.colorStep or 0) * 0.37
			self:_place(v, def, math.sin(t * 1.6 + phase) * 0.35)
			if doHue then
				self:_styleView(v, def, def.colorStep + t * 3)
			end
		end
	end
end

-- Cosmetic target highlight: nearest active balloon roughly in front within reach.
-- Purely visual; the server picks real targets.
function BalloonRenderer._updateTarget(self: any)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bestD = nil, 7.5
	if root then
		local look = root.CFrame.LookVector
		for id, v in self.views do
			local def = self.defs[id]
			if def then
				local to = Vector3.new(def.pos.x, def.pos.y, def.pos.z) - root.Position
				local d = to.Magnitude
				if d < bestD and (d < 2 or look:Dot(to.Unit) > 0.2) then
					best, bestD = id, d
				end
			end
		end
	end
	if best ~= self.target then
		self.target = best
		if not self.highlight then
			local h = Instance.new("Highlight")
			h.Name = "PopParadeTarget"
			h.FillTransparency = 1
			h.OutlineColor = Color3.new(1, 1, 1)
			h.OutlineTransparency = 0.1
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = self.folder
			self.highlight = h
		end
		local hl = self.highlight :: Highlight
		hl.Adornee = if best and self.views[best] then self.views[best].model else nil
	end
end

function BalloonRenderer.viewCount(self: any): number
	local n = 0
	for _ in self.views do
		n += 1
	end
	return n
end

function BalloonRenderer.destroy(self: any)
	self.maid:clean()
	table.clear(self.views)
end

return BalloonRenderer
