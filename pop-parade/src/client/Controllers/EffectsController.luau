--!strict
-- Pooled, capped world effects: pop bursts (confetti), ring flashes, celebrations and the visual
-- fallbacks used while sound assets are missing. Reduced Effects = fewer particles, no rings.
-- Everything is client-local presentation driven by server-confirmed events.

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Pool = require(script.Parent.Parent.Util.Pool)

local EffectsController = {}
EffectsController.__index = EffectsController

local MAX_BURSTS_PER_SEC = 30
local CULL_DISTANCE = 160

local function rgbSeq(colors: { any }): ColorSequence
	local keys = {}
	local n = #colors
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new(if n == 1 then 0 else (i - 1) / (n - 1), Color3.new(c.r, c.g, c.b)))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
	end
	return ColorSequence.new(keys)
end

function EffectsController.new(Content: any)
	local self = setmetatable({
		Content = Content,
		reduced = false,
		burstTimes = {} :: { number },
	}, EffectsController)
	local folder = Instance.new("Folder")
	folder.Name = "PopParadeEffects"
	folder.Parent = Workspace
	self.folder = folder

	self.bursts = Pool.new(function()
		local att = Instance.new("Attachment")
		att.Name = "Burst"
		att.Parent = Workspace.Terrain
		local pe = Instance.new("ParticleEmitter")
		pe.Enabled = false
		pe.Lifetime = NumberRange.new(0.6, 1.1)
		pe.Speed = NumberRange.new(12, 22)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Acceleration = Vector3.new(0, -30, 0)
		pe.Drag = 2
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-300, 300)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.2) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
		pe.Squash = NumberSequence.new(0.6)
		pe.Parent = att
		return att
	end, function(att: Attachment)
		att.WorldPosition = Vector3.new(0, -500, 0)
	end, 24)

	self.rings = Pool.new(function()
		local p = Instance.new("Part")
		p.Name = "Ring"
		p.Shape = Enum.PartType.Ball
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		p.Parent = folder
		return p
	end, function(p: Part)
		p.Transparency = 1
		p.CFrame = CFrame.new(0, -500, 0)
	end, 16)
	return self
end

function EffectsController.setReduced(self: any, reduced: boolean)
	self.reduced = reduced
end

local function cameraPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

function EffectsController._budget(self: any): boolean
	local now = os.clock()
	local kept = {}
	for _, t in self.burstTimes do
		if now - t < 1 then
			table.insert(kept, t)
		end
	end
	self.burstTimes = kept
	if #kept >= MAX_BURSTS_PER_SEC then
		return false
	end
	table.insert(self.burstTimes, now)
	return true
end

function EffectsController.ring(self: any, position: Vector3, color: Color3, maxSize: number, duration: number)
	if self.reduced then
		return
	end
	local p = self.rings:acquire()
	if not p then
		return
	end
	p.Color = color
	p.Size = Vector3.one * 0.5
	p.CFrame = CFrame.new(position)
	p.Transparency = 0.35
	local tw = TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * maxSize, Transparency = 1 })
	tw.Completed:Once(function()
		self.rings:release(p)
	end)
	tw:Play()
end

-- Confetti pop burst. `fxId` is the equipped PopEffect for the popping player (local or default).
function EffectsController.pop(self: any, position: Vector3, balloonColor: Color3, fxId: string?)
	if (position - cameraPos()).Magnitude > CULL_DISTANCE or not self:_budget() then
		return
	end
	local desc = self.Content.VisualCatalog.get(fxId or "popfx.confetti")
	local style = desc.style or {}
	local att = self.bursts:acquire()
	if att then
		att.WorldPosition = position
		local pe = att:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter
		local colors = table.clone(desc.colors)
		table.insert(colors, 1, { r = balloonColor.R, g = balloonColor.G, b = balloonColor.B })
		pe.Color = rgbSeq(colors)
		pe.Speed = NumberRange.new((style.speed or 18) * 0.7, style.speed or 18)
		local count = style.pieces or 10
		pe:Emit(if self.reduced then math.max(3, math.floor(count / 3)) else count)
		task.delay(1.3, function()
			self.bursts:release(att)
		end)
	end
	self:ring(position, balloonColor, if style.ring then 9 else 6, 0.25)
end

function EffectsController.celebrate(self: any, position: Vector3, big: boolean)
	for i = 1, if self.reduced then 1 else (if big then 5 else 2) do
		task.delay((i - 1) * 0.12, function()
			local offset = Vector3.new((math.random() - 0.5) * 10, math.random() * 6, (math.random() - 0.5) * 10)
			self:pop(position + offset, Color3.fromHSV(math.random(), 0.6, 1), "popfx.starburst_deluxe")
		end)
	end
end

-- Stand-ins for missing sound files: tiny, quick, readable.
function EffectsController.fallbackCue(self: any, kind: string, position: Vector3)
	if kind == "none" then
		return
	end
	local color = if kind == "sparkle" then Color3.fromRGB(255, 220, 120) elseif kind == "ground_warning" or kind == "flash" then Color3.fromRGB(255, 90, 90) else Color3.new(1, 1, 1)
	self:ring(position, color, if kind == "ground_warning" then 14 else 4, 0.18)
end

function EffectsController.destroy(self: any)
	self.bursts:destroy()
	self.rings:destroy()
	self.folder:Destroy()
end

return EffectsController
