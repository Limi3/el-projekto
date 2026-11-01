--!strict
-- Item card used by Inventory, Shop and Sound: procedural preview (colour swatch + icon),
-- name, honest acquisition/status line and one action button.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local ItemCard = {}

export type Card = { frame: Frame, status: TextLabel, button: TextButton, name: TextLabel }

function ItemCard.new(parent: Instance, Content: any, itemId: string, order: number, buttonText: string, onClick: () -> ()): Card
	local desc = Content.VisualCatalog.get(itemId)
	local S = Content.Strings
	local card = Kit.new("Frame", { Name = itemId, BackgroundColor3 = Theme.color.white, Size = UDim2.new(1, 0, 0, 92), LayoutOrder = order, Parent = parent })
	Kit.corner(14).Parent = card
	Kit.stroke(if desc.premiumLook then Theme.color.golden else Theme.color.paperDim, 2).Parent = card
	-- preview swatch: gradient of the item's colours + its icon
	local sw = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(68, 68), Position = UDim2.fromOffset(12, 12), Parent = card })
	Kit.corner(14).Parent = sw
	local keys = {}
	for i, c in desc.colors do
		table.insert(keys, ColorSequenceKeypoint.new(if #desc.colors == 1 then 0 else (i - 1) / (#desc.colors - 1), Color3.new(c.r, c.g, c.b)))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
	end
	Kit.new("UIGradient", { Color = ColorSequence.new(keys), Rotation = 45, Parent = sw })
	local ic = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.6, 0.6), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = sw })
	Icons.draw(desc.icon, ic, Theme.color.white)
	local name = Kit.label(S.t(desc.nameKey), { font = Theme.font.display, size = 19, frameSize = UDim2.new(1, -250, 0, 26) })
	name.Position = UDim2.fromOffset(92, 12)
	name.Parent = card
	local status = Kit.label("", { size = 14, color = Theme.color.inkSoft, frameSize = UDim2.new(1, -250, 0, 44) })
	status.Position = UDim2.fromOffset(92, 40)
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Parent = card
	local btn = Kit.button({ text = buttonText, color = Theme.color.secondary, size = UDim2.fromOffset(140, 56), onClick = onClick })
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -12, 0.5, 0)
	btn.Parent = card
	return { frame = card, status = status, button = btn, name = name }
end

return ItemCard
