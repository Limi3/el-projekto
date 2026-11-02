--!strict
-- Primary menu: six one-word icon buttons (Needle, Speed, Attack, Sound, Inventory, Shop) in a
-- 2x3 grid on the left edge, above the mobile thumbstick and away from the jump button.
-- "More" opens a small secondary menu: Wheel, Rewards, Journal, Settings.
-- Every button: icon + word (never colour alone), tooltip, gamepad focus.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local Menu = {}
Menu.__index = Menu

local PRIMARY = { "Needle", "Speed", "Attack", "Sound", "Inventory", "Shop" }
local SECONDARY = { "Wheel", "Rewards", "Journal", "Settings" }

local function colorFor(name: string): Color3
	if Theme.upgrade[name] then
		return Theme.upgrade[name]
	elseif name == "Sound" then
		return Color3.fromRGB(120, 120, 255)
	elseif name == "Inventory" then
		return Color3.fromRGB(40, 190, 170)
	elseif name == "Shop" then
		return Theme.color.primary
	elseif name == "Wheel" then
		return Theme.color.tickets
	elseif name == "Rewards" then
		return Theme.color.coins
	elseif name == "Journal" then
		return Theme.color.golden
	end
	return Theme.color.inkSoft
end

local function tile(name: string, label: string, onClick: () -> (), size: number): TextButton
	local color = colorFor(name)
	local btn = Kit.button({ name = name, color = color, size = UDim2.fromOffset(size, size), onClick = onClick })
	local content = (btn :: any).Content
	content:ClearAllChildren()
	local icon = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.46, 0.46), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12), Parent = content })
	Icons.draw(name, icon, Theme.color.white)
	local lbl = Kit.label(label, { font = Theme.font.display, size = 15, color = Theme.color.white, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 20), stroke = true, strokeThickness = 1.5, wrap = false })
	lbl.AnchorPoint = Vector2.new(0.5, 1)
	lbl.Position = UDim2.new(0.5, 0, 1, -4)
	lbl.TextScaled = true
	Kit.new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 11, Parent = lbl })
	lbl.Parent = content
	local badge = Kit.new("TextLabel", {
		Name = "Badge",
		Text = "!",
		FontFace = Theme.font.display,
		TextSize = 16,
		TextColor3 = Theme.color.white,
		BackgroundColor3 = Theme.color.bad,
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Visible = false,
		ZIndex = 3,
		Parent = btn,
	})
	Kit.corner(99).Parent = badge
	Kit.stroke(Theme.color.white, 2).Parent = badge
	return btn
end

function Menu.new(parent: Instance, Content: any, tooltipLayer: Instance, onOpen: (string) -> ())
	local S = Content.Strings
	local self = setmetatable({ buttons = {} :: { [string]: TextButton } }, Menu)
	local size = Theme.size.menuButton
	local gap = 8
	local root = Kit.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.6, 0),
		Size = UDim2.fromOffset(size * 2 + gap, size * 4 + gap * 3),
		Parent = parent,
	})
	self.root = root
	-- Buttons live in their own grid frame; the More pop-up is a sibling (a child of a
	-- UIGridLayout container would be laid out as a grid cell).
	local grid = Kit.new("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	self.grid = grid
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(size, size),
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 2,
		Parent = grid,
	})
	for i, name in PRIMARY do
		local b = tile(name, S.t("menu." .. name), function()
			onOpen(name)
		end, size)
		b.LayoutOrder = i
		b.Parent = grid
		Kit.attachTooltip(b, S.t("tip." .. name), tooltipLayer)
		self.buttons[name] = b
	end

	-- secondary menu toggle
	local more = tile("More", S.t("menu.More"), function()
		self:toggleMore()
	end, size)
	more.LayoutOrder = 7
	more.Parent = grid
	Kit.attachTooltip(more, S.t("tip.More"), tooltipLayer)
	self.buttons.More = more

	local pop = Kit.new("Frame", {
		Name = "MoreMenu",
		BackgroundColor3 = Theme.color.paper,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 10, 1, 0),
		Size = UDim2.fromOffset(210, 4 * 52 + 3 * 6 + 20),
		Visible = false,
		ZIndex = Theme.zIndex.menu,
		Parent = root,
	})
	Kit.corner().Parent = pop
	Kit.stroke(Theme.color.ink, 2, 0.6).Parent = pop
	Kit.padding(10).Parent = pop
	Kit.list(Enum.FillDirection.Vertical, 6).Parent = pop
	for i, name in SECONDARY do
		local b = Kit.button({
			name = name,
			text = S.t("menu." .. name),
			color = colorFor(name),
			icon = Icons.fn(name),
			size = UDim2.new(1, 0, 0, 52),
			order = i,
			onClick = function()
				self:toggleMore(false)
				onOpen(name)
			end,
		})
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Parent = pop
		local badge = Kit.new("TextLabel", { Name = "Badge", Text = "!", FontFace = Theme.font.display, TextSize = 16, TextColor3 = Theme.color.white, BackgroundColor3 = Theme.color.bad, Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Visible = false, Parent = b })
		Kit.corner(99).Parent = badge
		self.buttons[name] = b
	end
	self.more = pop
	return self
end

function Menu.toggleMore(self: any, force: boolean?)
	local show = if force == nil then not self.more.Visible else force
	self.more.Visible = show
	if show then
		Kit.focus(self.buttons.Wheel)
	end
end

function Menu.setBadge(self: any, name: string, on: boolean)
	local b = self.buttons[name]
	local badge = b and b:FindFirstChild("Badge")
	if badge then
		(badge :: TextLabel).Visible = on
	end
end

function Menu.focusFirst(self: any)
	Kit.focus(self.buttons.Needle)
end

-- Phones: 3 columns x 3 rows so the grid ends above the dynamic thumbstick area.
function Menu.setCompact(self: any, compact: boolean)
	local size = Theme.size.menuButton
	local gap = 8
	local cols = if compact then 3 else 2
	local rows = math.ceil(7 / cols)
	local layout = self.grid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout.FillDirectionMaxCells = cols
	end
	self.root.Size = UDim2.fromOffset(size * cols + gap * (cols - 1), size * rows + gap * (rows - 1))
	-- Desktop: centred low enough on the left edge to clear Roblox's chat window (top-left).
	-- Phones: 3x3 higher up so it ends above the dynamic thumbstick (chat is collapsed there).
	self.root.Position = UDim2.new(0, 12, if compact then 0.36 else 0.6, 0)
	self.more.AnchorPoint = if compact then Vector2.new(0, 0) else Vector2.new(0, 1)
	self.more.Position = if compact then UDim2.new(1, 10, 0, 0) else UDim2.new(1, 10, 1, 0)
end

function Menu.setVisible(self: any, visible: boolean)
	self.root.Visible = visible
end

return Menu
