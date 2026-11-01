--!strict
-- Shared colour language so world props and HUD agree (kiosk colours = upgrade button colours).
-- Colour is never the only signal: every coded thing also has a label and an icon.

local function rgb(r: number, g: number, b: number)
	return { r = r / 255, g = g / 255, b = b / 255 }
end

return {
	upgrade = {
		Needle = rgb(255, 92, 110), -- red-pink
		Speed = rgb(60, 200, 255), -- sky
		Attack = rgb(255, 160, 50), -- orange
		Hits = rgb(160, 110, 255), -- violet
		Life = rgb(90, 210, 120), -- green
	},
	currency = {
		Coins = rgb(255, 205, 60),
		XP = rgb(150, 110, 255),
		Tickets = rgb(80, 220, 200),
	},
	rarity = {
		Common = rgb(190, 195, 205),
		Uncommon = rgb(100, 215, 120),
		Rare = rgb(70, 160, 255),
		Epic = rgb(190, 100, 255),
		Legendary = rgb(255, 190, 40),
	},
	status = {
		damage = rgb(255, 255, 255),
		coins = rgb(255, 205, 60),
		xp = rgb(170, 140, 255),
		hurt = rgb(255, 80, 80),
		good = rgb(90, 210, 120),
		warn = rgb(255, 170, 40),
	},
	golden = rgb(255, 200, 40),
	ink = rgb(40, 34, 70), -- primary text on light panels
	paper = rgb(255, 250, 242), -- panel background
}
