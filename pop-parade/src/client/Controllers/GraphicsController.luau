--!strict
-- Client-only post-processing ("toy parade" look). Every effect lives in Lighting on THIS client
-- only, so it never affects other players or the server, and each one can be switched off in
-- Settings (saved through A as player settings; applied locally right away).
--
--   dof      Depth of field: focus follows your character, the far background softens (tilt-shift toy
--            look). Also blurs the world behind open menus.
--   bloom    Soft glow on bright/neon parts (golden balloons, knots, ribbons).
--   sunRays  Light shafts when looking toward the sun.
--   shadows  Real-time shadows (Lighting.GlobalShadows, local).
--
-- Reduced motion & effects forces DoF/menu blur and sun rays off (comfort), whatever the toggles say.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Maid = require(script.Parent.Parent.Util.Maid)

local GraphicsController = {}
GraphicsController.__index = GraphicsController

export type Flags = { dof: boolean, bloom: boolean, sunRays: boolean, shadows: boolean }

-- tuned live in Studio (Future lighting). First pass (radius 28 / far 0.32, bloom threshold 1.4)
-- washed the pale floors out to white; these values keep the pastels crisp.
local DOF = { inFocusRadius = 38, farIntensity = 0.22, nearIntensity = 0.05, minFocus = 8, maxFocus = 60 }
local MENU_BLUR = 12

local function make(className: string, name: string): any
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	return inst
end

function GraphicsController.new()
	local self = setmetatable({
		maid = Maid.new(),
		flags = { dof = true, bloom = true, sunRays = true, shadows = true } :: Flags,
		reduced = false,
		menuOpen = false,
		focus = 20,
	}, GraphicsController)

	local dof = make("DepthOfFieldEffect", "PopParadeDOF")
	dof.InFocusRadius = DOF.inFocusRadius
	dof.FarIntensity = DOF.farIntensity
	dof.NearIntensity = DOF.nearIntensity
	dof.FocusDistance = 20
	dof.Parent = Lighting
	self.dof = dof

	local bloom = make("BloomEffect", "PopParadeBloom")
	bloom.Intensity = 0.45
	bloom.Size = 24
	bloom.Threshold = 2.4 -- only neon/very bright parts glow; pale floors must stay below this
	bloom.Parent = Lighting
	self.bloom = bloom

	local rays = make("SunRaysEffect", "PopParadeSunRays")
	rays.Intensity = 0.025
	rays.Spread = 0.55
	rays.Parent = Lighting
	self.rays = rays

	local blur = make("BlurEffect", "PopParadeMenuBlur")
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting
	self.blur = blur

	-- soft pastel clouds (client-only, cheap)
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Name = "PopParadeClouds"
		clouds.Cover = 0.5
		clouds.Density = 0.45
		clouds.Color = Color3.fromRGB(255, 244, 252)
		clouds.Parent = terrain
		self.maid:give(clouds)
	end

	for _, inst in { dof, bloom, rays, blur } do
		self.maid:give(inst)
	end

	-- focus follows the local character (smoothed so camera zoom doesn't pump the blur)
	self.maid:give(RunService.RenderStepped:Connect(function(dt)
		self:_updateFocus(dt)
	end))
	self:_apply()
	return self
end

function GraphicsController._updateFocus(self: any, dt: number)
	if not self.dof.Enabled then
		return
	end
	local cam = Workspace.CurrentCamera
	local char = Players.LocalPlayer.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not cam or not head then
		return
	end
	local target = math.clamp((cam.CFrame.Position - head.Position).Magnitude, DOF.minFocus, DOF.maxFocus)
	self.focus += (target - self.focus) * math.clamp(dt * 6, 0, 1)
	self.dof.FocusDistance = self.focus
end

function GraphicsController._apply(self: any)
	local f = self.flags
	local comfort = self.reduced
	self.dof.Enabled = f.dof and not comfort
	self.bloom.Enabled = f.bloom
	self.rays.Enabled = f.sunRays and not comfort
	Lighting.GlobalShadows = f.shadows
	self:_applyBlur()
end

function GraphicsController._applyBlur(self: any)
	local want = self.menuOpen and self.flags.dof and not self.reduced
	if want then
		self.blur.Enabled = true
		TweenService:Create(self.blur, TweenInfo.new(0.2), { Size = MENU_BLUR }):Play()
	else
		self.blur.Size = 0
		self.blur.Enabled = false
	end
end

-- key: "dof" | "bloom" | "sunRays" | "shadows"; nil value means "default on"
function GraphicsController.set(self: any, key: string, value: boolean?)
	if self.flags[key] == nil then
		return
	end
	self.flags[key] = value ~= false
	self:_apply()
end

function GraphicsController.setReduced(self: any, reduced: boolean)
	self.reduced = reduced
	self:_apply()
end

function GraphicsController.setMenuOpen(self: any, open: boolean)
	if self.menuOpen ~= open then
		self.menuOpen = open
		self:_applyBlur()
	end
end

function GraphicsController.destroy(self: any)
	self.maid:clean()
end

return GraphicsController
