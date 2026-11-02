--!strict
-- Big centre-top title card for moments: boss intro, victory, run defeat, parkour finish.
-- One banner at a time; a newer banner replaces the current one. Purely presentational:
-- it never states reward amounts (those arrive as server-confirmed state deltas).

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Banner = {}
Banner.__index = Banner

function Banner.new(gui: Instance)
	local self = setmetatable({ token = 0 }, Banner)
	local frame = Kit.new("Frame", {
		Name = "MomentBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200), -- below XP bar, pills and boss bar
		Size = UDim2.fromOffset(560, 112),
		BackgroundColor3 = Theme.color.paper,
		Visible = false,
		ZIndex = Theme.zIndex.banner,
		Parent = gui,
	})
	Kit.corner(22).Parent = frame
	self.stroke = Kit.stroke(Theme.color.golden, 5)
	self.stroke.Parent = frame
	local title = Kit.label("", { font = Theme.font.display, size = 44, color = Theme.color.golden, frameSize = UDim2.new(1, -24, 0, 58), stroke = true, wrap = false })
	title.Position = UDim2.fromOffset(12, 8)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = Theme.zIndex.banner + 1
	title.Parent = frame
	local sub = Kit.label("", { font = Theme.font.bold, size = 18, color = Theme.color.ink, frameSize = UDim2.new(1, -24, 0, 40) })
	sub.Position = UDim2.fromOffset(12, 66)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.ZIndex = Theme.zIndex.banner + 1
	sub.Parent = frame
	self.frame = frame
	self.title = title
	self.sub = sub
	self.scale = Kit.new("UIScale", { Parent = frame })
	return self
end

-- kind: "gold" | "good" | "bad" | "boss"
function Banner.show(self: any, title: string, subtitle: string?, kind: string?, seconds: number?)
	local color = if kind == "bad" then Theme.color.bad elseif kind == "good" then Theme.color.good elseif kind == "boss" then Theme.color.primary else Theme.color.golden
	self.token += 1
	local token = self.token
	self.title.Text = title
	self.title.TextColor3 = color
	self.stroke.Color = color
	self.sub.Text = subtitle or ""
	self.sub.Visible = subtitle ~= nil and subtitle ~= ""
	self.frame.Visible = true
	self.scale.Scale = if Kit.reducedMotion then 1 else 0.6
	if not Kit.reducedMotion then
		Kit.tween(self.scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	end
	task.delay(seconds or 3.5, function()
		if self.token == token then
			self.frame.Visible = false
		end
	end)
end

function Banner.hide(self: any)
	self.token += 1
	self.frame.Visible = false
end

return Banner
