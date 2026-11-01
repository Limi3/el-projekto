--!strict
-- Visual themes for stages and the hub. Presentation only: no rewards, HP, prices or unlock rules
-- (those belong to A's balance/contract). `status` is honest about what is actually built:
--   "playable"  – geometry exists in WorldBuilder and has passed structural checks
--   "design"    – documented design + data-driven parameters; NOT a finished world
-- Never present a "design" theme to players as available content.

local Themes = {}

export type ThemeDef = {
	key: string,
	displayKey: string,
	kind: "material" | "confection" | "hub",
	material: string, -- balloon material key (Materials.INFO)
	status: "playable" | "design",
	paletteOffset: number, -- shifts the 1,000-step spectrum so each theme opens on a different hue
	floor: { r: number, g: number, b: number },
	trim: { r: number, g: number, b: number },
	accent: { r: number, g: number, b: number },
	sky: { top: { r: number, g: number, b: number }, horizon: { r: number, g: number, b: number } },
	surfaceMaterial: string,
	bossKey: string?,
	signature: string, -- one-line route identity for designers
}

local function rgb(r: number, g: number, b: number)
	return { r = r / 255, g = g / 255, b = b / 255 }
end

Themes.LIST = {
	{
		key = "hub",
		displayKey = "theme.hub",
		kind = "hub",
		material = "rubber",
		status = "playable",
		paletteOffset = 0,
		floor = rgb(255, 236, 205),
		trim = rgb(255, 120, 150),
		accent = rgb(80, 190, 255),
		sky = { top = rgb(120, 200, 255), horizon = rgb(255, 225, 240) },
		surfaceMaterial = "SmoothPlastic",
		signature = "Bright carnival plaza; striped tents, round stalls, balloon arches.",
	},
	{
		key = "rubber",
		displayKey = "theme.rubber",
		kind = "material",
		material = "rubber",
		status = "playable",
		paletteOffset = 0,
		floor = rgb(255, 214, 120),
		trim = rgb(255, 110, 90),
		accent = rgb(110, 220, 160),
		sky = { top = rgb(110, 195, 255), horizon = rgb(255, 230, 200) },
		surfaceMaterial = "SmoothPlastic",
		bossKey = "boss.king_puffer",
		signature = "Bouncy toy blocks; branching rainbow lanes climbing to King Puffer's drum arena.",
	},
	{
		key = "wood",
		displayKey = "theme.wood",
		kind = "material",
		material = "wood",
		status = "design",
		paletteOffset = 200,
		floor = rgb(196, 150, 100),
		trim = rgb(120, 80, 50),
		accent = rgb(120, 200, 110),
		sky = { top = rgb(150, 210, 240), horizon = rgb(250, 230, 190) },
		surfaceMaterial = "WoodPlanks",
		bossKey = "boss.timber_toad",
		signature = "Toy workshop: plank bridges, see-saws, a hollow carved sculpture.",
	},
	{
		key = "candy",
		displayKey = "theme.candy",
		kind = "confection",
		material = "rubber",
		status = "design",
		paletteOffset = 850,
		floor = rgb(255, 200, 225),
		trim = rgb(235, 60, 90),
		accent = rgb(255, 255, 255),
		sky = { top = rgb(255, 190, 220), horizon = rgb(255, 245, 210) },
		surfaceMaterial = "SmoothPlastic",
		bossKey = "boss.sugar_swirl",
		signature = "Winding candy-cane routes; striped rails; gumdrop stepping stones.",
	},
	{
		key = "steel",
		displayKey = "theme.steel",
		kind = "material",
		material = "steel",
		status = "design",
		paletteOffset = 400,
		floor = rgb(160, 170, 185),
		trim = rgb(70, 80, 95),
		accent = rgb(255, 190, 60),
		sky = { top = rgb(140, 170, 210), horizon = rgb(220, 225, 235) },
		surfaceMaterial = "DiamondPlate",
		bossKey = "boss.rivet_rex",
		signature = "Clockwork factory: conveyor lanes, pistons on readable timers.",
	},
	{
		key = "chocolate",
		displayKey = "theme.chocolate",
		kind = "confection",
		material = "rubber",
		status = "design",
		paletteOffset = 60,
		floor = rgb(120, 75, 50),
		trim = rgb(70, 40, 25),
		accent = rgb(255, 220, 160),
		sky = { top = rgb(230, 170, 130), horizon = rgb(255, 225, 190) },
		surfaceMaterial = "SmoothPlastic",
		bossKey = "boss.cocoa_shell",
		signature = "Breakable chocolate-shell styling; wafer bridges over caramel.",
	},
	{
		key = "gold",
		displayKey = "theme.gold",
		kind = "material",
		material = "gold",
		status = "design",
		paletteOffset = 600,
		floor = rgb(255, 230, 150),
		trim = rgb(200, 150, 40),
		accent = rgb(255, 255, 255),
		sky = { top = rgb(255, 220, 140), horizon = rgb(255, 245, 220) },
		surfaceMaterial = "SmoothPlastic",
		bossKey = "boss.gilded_gust",
		signature = "Treasure vault: gold-framed rainbow balloons, coin-stack platforms.",
	},
	{
		key = "ice_cream",
		displayKey = "theme.ice_cream",
		kind = "confection",
		material = "rubber",
		status = "design",
		paletteOffset = 520,
		floor = rgb(225, 245, 255),
		trim = rgb(255, 160, 200),
		accent = rgb(140, 220, 200),
		sky = { top = rgb(170, 225, 255), horizon = rgb(255, 250, 240) },
		surfaceMaterial = "Glacier",
		bossKey = "boss.sundae_supreme",
		signature = "Slippery-LOOKING scoops with normal grip; waffle-cone towers.",
	},
	{
		key = "diamond",
		displayKey = "theme.diamond",
		kind = "material",
		material = "diamond",
		status = "design",
		paletteOffset = 750,
		floor = rgb(220, 240, 255),
		trim = rgb(150, 190, 255),
		accent = rgb(255, 140, 220),
		sky = { top = rgb(60, 80, 160), horizon = rgb(200, 180, 255) },
		surfaceMaterial = "Glass",
		bossKey = "boss.prism_prime",
		signature = "Crystal caverns: faceted light bridges, refracted rainbow beams.",
	},
	{
		key = "halloween",
		displayKey = "theme.halloween",
		kind = "confection",
		material = "rubber",
		status = "design",
		paletteOffset = 80,
		floor = rgb(90, 70, 110),
		trim = rgb(255, 140, 40),
		accent = rgb(160, 255, 140),
		sky = { top = rgb(60, 50, 110), horizon = rgb(255, 160, 90) },
		surfaceMaterial = "SmoothPlastic",
		bossKey = "boss.pumpkin_puff",
		signature = "Playful pumpkins and friendly ghost balloons; no graphic horror. Placement is config, not calendar.",
	},
} :: { ThemeDef }

Themes.BY_KEY = {} :: { [string]: ThemeDef }
for _, t in Themes.LIST do
	Themes.BY_KEY[t.key] = t
end

function Themes.get(key: string): ThemeDef
	return Themes.BY_KEY[key] or Themes.BY_KEY.hub
end

return Themes
