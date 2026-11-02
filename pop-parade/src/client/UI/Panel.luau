--!strict
-- Shared modal panel: title + icon, close button, scrollable body, open/close animation.
-- Opening never triggers a purchase prompt; panels only show state and send explicit requests.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local Panel = {}
Panel.__index = Panel

export type Panel = {
	frame: Frame,
	body: ScrollingFrame,
	header: Frame,
	isOpen: boolean,
	open: (self: Panel) -> (),
	close: (self: Panel) -> (),
	setTitle: (self: Panel, text: string, iconKey: string?) -> (),
	closeButton: TextButton,
}

function Panel.new(layer: Instance, opts: { name: string, title: string, icon: string, color: Color3, width: number?, height: number?, closeText: string, onClose: (() -> ())? }): Panel
	local self = setmetatable({ isOpen = false, _onClose = opts.onClose }, Panel)
	local frame = Kit.new("Frame", {
		Name = opts.name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		-- height follows the screen on short (landscape phone) displays, capped at the design height
		Size = UDim2.new(0, opts.width or 560, 0.84, 0),
		BackgroundColor3 = Theme.color.paper,
		Visible = false,
		ZIndex = Theme.zIndex.panel,
		Parent = layer,
	})
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(opts.width or 560, opts.height or 520), Parent = frame })
	Kit.corner(18).Parent = frame
	Kit.stroke(opts.color, 4).Parent = frame
	local header = Kit.new("Frame", { Name = "Header", BackgroundColor3 = opts.color, Size = UDim2.new(1, 0, 0, 58), Parent = frame })
	Kit.corner(18).Parent = header
	-- square off the header's lower corners
	Kit.new("Frame", { BackgroundColor3 = opts.color, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), Parent = header })
	local icon = Kit.new("Frame", { Name = "TitleIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(14, 12), Parent = header })
	Icons.draw(opts.icon, icon, Theme.color.white)
	self.titleIcon = icon
	local title = Kit.label(opts.title, { font = Theme.font.display, size = Theme.size.title, color = Theme.color.white, frameSize = UDim2.new(1, -140, 1, 0), stroke = true, wrap = false })
	title.Position = UDim2.fromOffset(58, 0)
	title.Parent = header
	self.titleLabel = title
	local close = Kit.button({
		text = "X",
		color = Theme.color.white,
		textColor = opts.color,
		style = "solid",
		size = UDim2.fromOffset(Theme.size.touchMin, Theme.size.touchMin),
		textSize = 22,
		onClick = function()
			self:close()
		end,
	})
	close.Name = "Close"
	close:SetAttribute("AccessibleLabel", opts.closeText)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -8, 0.5, 0)
	close.Parent = header
	local body = Kit.new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = opts.color,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	})
	Kit.padding(14).Parent = body
	Kit.list(Enum.FillDirection.Vertical, 10).Parent = body
	self.frame = frame
	self.body = body
	self.header = header
	self.closeButton = close
	self.scale = Kit.new("UIScale", { Parent = frame })
	return self :: any
end

function Panel.open(self: any)
	if self.isOpen then
		return
	end
	self.isOpen = true
	self.frame.Visible = true
	self.scale.Scale = 0.9
	Kit.tween(self.scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	Kit.focus(self.closeButton)
end

function Panel.close(self: any)
	if not self.isOpen then
		return
	end
	self.isOpen = false
	self.frame.Visible = false
	if self._onClose then
		self._onClose()
	end
end

function Panel.setTitle(self: any, text: string, iconKey: string?)
	self.titleLabel.Text = text
	if iconKey then
		self.titleIcon:ClearAllChildren()
		Icons.draw(iconKey, self.titleIcon, Theme.color.white)
	end
end

-- Section heading inside a panel body
function Panel.section(parent: Instance, text: string, order: number): TextLabel
	local lbl = Kit.label(text, { font = Theme.font.display, size = 20, color = Theme.color.ink, order = order })
	lbl.Parent = parent
	return lbl
end

-- Card container (rounded white box with a horizontal layout)
function Panel.card(parent: Instance, order: number, height: number?, accent: Color3?): Frame
	local card = Kit.new("Frame", { BackgroundColor3 = Theme.color.white, Size = UDim2.new(1, 0, 0, height or 86), LayoutOrder = order, Parent = parent })
	Kit.corner(14).Parent = card
	Kit.stroke(accent or Theme.color.paperDim, 2).Parent = card
	return card
end

return Panel
