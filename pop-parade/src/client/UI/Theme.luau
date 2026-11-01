--!strict
-- Visual tokens for every screen: one rounded, bright, readable style.
-- Colours come from shared Branding so HUD buttons match the world kiosks.

local Theme = {}

local function c(rgb: { r: number, g: number, b: number }): Color3
	return Color3.new(rgb.r, rgb.g, rgb.b)
end

function Theme.init(Content: any)
	local B = Content.Branding
	Theme.color = {
		ink = c(B.ink),
		inkSoft = Color3.fromRGB(100, 94, 130),
		paper = c(B.paper),
		paperDim = Color3.fromRGB(240, 233, 250),
		white = Color3.new(1, 1, 1),
		shadow = Color3.fromRGB(40, 20, 70),
		overlay = Color3.fromRGB(20, 10, 40),
		primary = Color3.fromRGB(255, 92, 140),
		secondary = Color3.fromRGB(80, 170, 255),
		good = c(B.status.good),
		warn = c(B.status.warn),
		bad = c(B.status.hurt),
		coins = c(B.currency.Coins),
		xp = c(B.currency.XP),
		tickets = c(B.currency.Tickets),
		golden = c(B.golden),
		disabled = Color3.fromRGB(190, 186, 200),
		preview = Color3.fromRGB(255, 220, 60),
	}
	Theme.upgrade = {}
	for id, rgb in B.upgrade do
		Theme.upgrade[id] = c(rgb)
	end
	Theme.rarity = {}
	for id, rgb in B.rarity do
		Theme.rarity[id] = c(rgb)
	end
	Theme.fromRGB = c
end

Theme.font = {
	display = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
}

-- Base design size; UIScale maps it to the device. Touch targets stay >= 48 px at min scale.
Theme.DESIGN_HEIGHT = 720
Theme.MIN_SCALE = 0.72
Theme.MAX_SCALE = 1.25
Theme.size = {
	menuButton = 68,
	touchMin = 48,
	corner = 14,
	cornerSmall = 10,
	pad = 12,
	gap = 8,
	text = 18,
	textSmall = 15,
	textLarge = 24,
	title = 30,
}

Theme.zIndex = { hud = 1, menu = 5, panel = 20, modal = 40, toast = 60, banner = 80 }

return Theme
