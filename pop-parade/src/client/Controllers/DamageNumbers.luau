--!strict
-- Server-confirmed damage numbers above the LOCAL avatar, each with a small popped-balloon icon.
-- Rapid hits merge (DamageMerge); labels are pooled. Coins/XP gains are shown separately at the
-- HUD counters (never mixed with damage). AFK stations get giant, station-local numbers.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DamageMerge = require(script.Parent.Parent.Util.DamageMerge)
local Format = require(script.Parent.Parent.Util.Format)
local Icons = require(script.Parent.Parent.UI.Icons)
local Theme = require(script.Parent.Parent.UI.Theme)

local DamageNumbers = {}
DamageNumbers.__index = DamageNumbers

local LIFETIME = 0.9
local MAX_LABELS = 5

local function makeLabel(parent: Instance, big: boolean): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, if big then 1 else 0.34)
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.fromScale(0.5, 1)
	holder.Visible = false
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(0.18, 0.9)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Position = UDim2.fromScale(0.38, 0.5)
	icon.Parent = holder
	Icons.draw("popped", icon, Color3.new(1, 1, 1))
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Amount"
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(0.62, 1)
	lbl.Position = UDim2.fromScale(0.4, 0)
	lbl.FontFace = Theme.font.display
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 20, 70)
	stroke.Thickness = if big then 4 else 2.5
	stroke.Parent = lbl
	lbl.Parent = holder
	holder.Parent = parent
	return holder
end

function DamageNumbers.new()
	local self = setmetatable({
		merge = DamageMerge.new(0.3, MAX_LABELS),
		labels = {} :: { [number]: Frame },
		free = {} :: { Frame },
		gui = nil :: BillboardGui?,
		reduced = false,
		stationGuis = {} :: { [string]: BillboardGui },
	}, DamageNumbers)
	local player = Players.LocalPlayer
	local function attach(char: Model)
		local head = char:WaitForChild("Head", 10)
		if not head then
			return
		end
		if self.gui then
			self.gui:Destroy()
		end
		table.clear(self.labels)
		table.clear(self.free)
		self.merge = DamageMerge.new(0.3, MAX_LABELS)
		local gui = Instance.new("BillboardGui")
		gui.Name = "PopParadeDamage"
		gui.Adornee = head :: BasePart
		gui.Size = UDim2.fromOffset(160, 140)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.Parent = player:WaitForChild("PlayerGui")
		self.gui = gui
		for _ = 1, MAX_LABELS do
			table.insert(self.free, makeLabel(gui, false))
		end
	end
	if player.Character then
		task.spawn(attach, player.Character)
	end
	player.CharacterAdded:Connect(attach)
	return self
end

function DamageNumbers.setReduced(self: any, v: boolean)
	self.reduced = v
end

function DamageNumbers._animate(self: any, holder: Frame, fresh: boolean)
	holder.Position = UDim2.fromScale(0.5, 1)
	local lbl = holder:FindFirstChild("Amount") :: TextLabel
	lbl.TextTransparency = 0
	if self.reduced then
		return
	end
	local sc = holder:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	sc.Parent = holder
	sc.Scale = if fresh then 1.35 else 1.2
	TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(holder, TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.45) }):Play()
end

function DamageNumbers.show(self: any, amount: number)
	if not self.gui then
		return
	end
	local now = os.clock()
	for _, e in self.merge:expire(now, LIFETIME) do
		local h = self.labels[e.id]
		if h then
			h.Visible = false
			self.labels[e.id] = nil
			table.insert(self.free, h)
		end
	end
	local kind, entry, evicted = self.merge:add(now, amount)
	if evicted and self.labels[evicted.id] then
		local h = self.labels[evicted.id]
		h.Visible = false
		self.labels[evicted.id] = nil
		table.insert(self.free, h)
	end
	local holder = self.labels[entry.id]
	if kind == "new" or not holder then
		holder = table.remove(self.free)
		if not holder then
			return
		end
		self.labels[entry.id] = holder
	end
	(holder:FindFirstChild("Amount") :: TextLabel).Text = Format.compact(entry.total)
	holder.Visible = true
	self:_animate(holder, kind == "new")
end

-- Giant numbers at a station balloon (premium AFK spectacle). Station-local damage only.
function DamageNumbers.showStation(self: any, stationId: string, anchor: BasePart, amount: number, premium: boolean)
	local gui = self.stationGuis[stationId]
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "StationDamage"
		gui.Adornee = anchor
		gui.Size = UDim2.fromOffset(if premium then 420 else 220, if premium then 160 else 80)
		gui.StudsOffsetWorldSpace = Vector3.new(0, if premium then 16 else 10, 0)
		gui.LightInfluence = 0
		gui.MaxDistance = 140
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		makeLabel(gui, true)
		self.stationGuis[stationId] = gui
	end
	local holder = gui:FindFirstChildOfClass("Frame") :: Frame
	local lbl = holder:FindFirstChild("Amount") :: TextLabel
	lbl.Text = Format.compact(amount)
	lbl.TextColor3 = if premium then Theme.color.golden else Color3.new(1, 1, 1)
	holder.Visible = true
	self:_animate(holder, true)
end

return DamageNumbers
