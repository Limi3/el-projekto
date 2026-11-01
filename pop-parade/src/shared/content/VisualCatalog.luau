--!strict
-- Presentation descriptors keyed by stable item ID.
-- B owns how things LOOK. A owns what they ARE (stats, rarity, ownership, costs, product links).
-- This file must never contain prices, odds, stat values, product IDs or secret coordinates.
--
-- Item IDs from the shared spec are used verbatim (skin.rubber_twist ... skin.wheel_founder).
-- Every other ID here is a B PROPOSAL listed in docs/b/CONTRACT_REQUESTS.md; if A's catalog uses
-- different IDs, rename here, never in A's files.
--
-- All visuals are procedural (Parts, Beams, Trails, ParticleEmitters with default textures) so the
-- game works with zero uploaded assets. `assetId` stays nil until the owner supplies a real,
-- licensed asset; see docs/b/ASSET_MANIFEST.md.

export type RGB = { r: number, g: number, b: number }

export type VisualDescriptor = {
	id: string,
	slot: "NeedleSkin" | "Trail" | "Wings" | "PopEffect" | "Sound" | "Accessory" | "Consumable",
	nameKey: string,
	descKey: string?,
	icon: string, -- procedural icon key understood by UI/Icons.luau
	colors: { RGB },
	premiumLook: boolean, -- richer animation/particles; NEVER implies extra stats
	style: { [string]: any }, -- renderer-specific parameters
	assetId: string?, -- real uploaded asset when available; nil = procedural
	acquisitionHint: string?, -- Strings key; A's state decides the truthful label at runtime
}

local function rgb(r: number, g: number, b: number): RGB
	return { r = r / 255, g = g / 255, b = b / 255 }
end

local RAINBOW = { rgb(255, 80, 90), rgb(255, 170, 60), rgb(255, 230, 80), rgb(90, 220, 120), rgb(80, 170, 255), rgb(170, 110, 255) }

local LIST: { VisualDescriptor } = {
	-- Needle skins (wheel collection; IDs from spec section 8)
	{
		id = "skin.rubber_twist",
		slot = "NeedleSkin",
		nameKey = "item.skin.rubber_twist",
		icon = "needle",
		colors = { rgb(255, 120, 120), rgb(255, 230, 230) },
		premiumLook = false,
		style = { shape = "twist", twists = 3, spin = 0.5 },
	},
	{
		id = "skin.candy_swirl",
		slot = "NeedleSkin",
		nameKey = "item.skin.candy_swirl",
		icon = "needle",
		colors = { rgb(255, 255, 255), rgb(240, 60, 100) },
		premiumLook = false,
		style = { shape = "stripes", stripes = 6, spin = 0.8 },
	},
	{
		id = "skin.chrome_spiral",
		slot = "NeedleSkin",
		nameKey = "item.skin.chrome_spiral",
		icon = "needle",
		colors = { rgb(210, 220, 235), rgb(120, 130, 150) },
		premiumLook = false,
		style = { shape = "spiral", material = "Metal", reflectance = 0.35, spin = 1.0 },
	},
	{
		id = "skin.neon_helix",
		slot = "NeedleSkin",
		nameKey = "item.skin.neon_helix",
		icon = "needle",
		colors = { rgb(60, 255, 210), rgb(255, 60, 220) },
		premiumLook = false,
		style = { shape = "helix", material = "Neon", spin = 1.4, glow = true },
	},
	{
		id = "skin.prism_crown",
		slot = "NeedleSkin",
		nameKey = "item.skin.prism_crown",
		icon = "crown",
		colors = RAINBOW,
		premiumLook = false,
		style = { shape = "crown", material = "Glass", spin = 0.6, sparkles = true, rainbow = true },
	},
	{
		-- Wheel-exclusive collectible (25 completed free spins). Never sold. Recognisable identity:
		-- a gold-and-navy carnival ticket-punch needle with a star finial and a little pennant.
		id = "skin.wheel_founder",
		slot = "NeedleSkin",
		nameKey = "item.skin.wheel_founder",
		descKey = "item.skin.wheel_founder.desc",
		icon = "star",
		colors = { rgb(255, 200, 60), rgb(30, 40, 90), rgb(255, 255, 255) },
		premiumLook = false,
		style = { shape = "founder", finial = "star", pennant = true, spin = 0.4 },
		acquisitionHint = "acq.wheel_exclusive",
	},
	{
		id = "skin.default",
		slot = "NeedleSkin",
		nameKey = "item.skin.default",
		icon = "needle",
		colors = { rgb(200, 205, 215), rgb(255, 90, 90) },
		premiumLook = false,
		style = { shape = "plain", spin = 0.3 },
	},

	-- Trails: earnable base + premium "deluxe" presentation (same capability: none)
	{
		id = "trail.rainbow",
		slot = "Trail",
		nameKey = "item.trail.rainbow",
		icon = "trail",
		colors = RAINBOW,
		premiumLook = false,
		style = { lifetime = 0.45, width = 1.2, particles = false },
	},
	{
		id = "trail.rainbow_deluxe",
		slot = "Trail",
		nameKey = "item.trail.rainbow_deluxe",
		icon = "trail",
		colors = RAINBOW,
		premiumLook = true,
		style = { lifetime = 0.8, width = 1.8, particles = true, sparkleRate = 14, shimmer = true },
	},
	{
		id = "trail.rocket",
		slot = "Trail",
		nameKey = "item.trail.rocket",
		icon = "rocket",
		colors = { rgb(255, 230, 120), rgb(255, 120, 40), rgb(120, 120, 130) },
		premiumLook = false,
		style = { lifetime = 0.5, width = 1.0, particles = false },
	},
	{
		id = "trail.rocket_deluxe",
		slot = "Trail",
		nameKey = "item.trail.rocket_deluxe",
		icon = "rocket",
		colors = { rgb(255, 250, 200), rgb(255, 140, 30), rgb(90, 90, 100) },
		premiumLook = true,
		style = { lifetime = 0.7, width = 1.4, particles = true, smoke = true, sparkleRate = 18 },
	},
	{
		id = "trail.neon",
		slot = "Trail",
		nameKey = "item.trail.neon",
		icon = "bolt",
		colors = { rgb(60, 255, 230), rgb(60, 120, 255) },
		premiumLook = false,
		style = { lifetime = 0.4, width = 0.8, particles = false, lightEmission = 1 },
	},
	{
		id = "trail.neon_deluxe",
		slot = "Trail",
		nameKey = "item.trail.neon_deluxe",
		icon = "bolt",
		colors = { rgb(255, 60, 230), rgb(60, 255, 230), rgb(255, 255, 120) },
		premiumLook = true,
		style = { lifetime = 0.75, width = 1.2, particles = true, lightEmission = 1, pulse = true, sparkleRate = 12 },
	},

	-- Wings: free basic (first legit boss) and paid ornate; identical double-jump capability
	{
		id = "wings.basic",
		slot = "Wings",
		nameKey = "item.wings.basic",
		descKey = "item.wings.desc",
		icon = "wings",
		colors = { rgb(255, 255, 255), rgb(170, 220, 255) },
		premiumLook = false,
		style = { shape = "paper", feathers = 3, flapOnJump = true },
		acquisitionHint = "acq.first_boss",
	},
	{
		id = "wings.ornate",
		slot = "Wings",
		nameKey = "item.wings.ornate",
		descKey = "item.wings.desc",
		icon = "wings",
		colors = { rgb(255, 210, 90), rgb(255, 120, 200), rgb(140, 120, 255) },
		premiumLook = true,
		style = { shape = "butterfly", feathers = 5, flapOnJump = true, sparkles = true, gradient = true },
	},

	-- Pop / confetti effects
	{
		id = "popfx.confetti",
		slot = "PopEffect",
		nameKey = "item.popfx.confetti",
		icon = "confetti",
		colors = RAINBOW,
		premiumLook = false,
		style = { pieces = 10, spread = 35, speed = 18 },
	},
	{
		id = "popfx.streamers",
		slot = "PopEffect",
		nameKey = "item.popfx.streamers",
		icon = "confetti",
		colors = { rgb(255, 255, 255), rgb(255, 100, 140), rgb(100, 200, 255) },
		premiumLook = false,
		style = { pieces = 8, spread = 25, speed = 14, streamers = true },
	},
	{
		id = "popfx.starburst_deluxe",
		slot = "PopEffect",
		nameKey = "item.popfx.starburst_deluxe",
		icon = "star",
		colors = { rgb(255, 230, 90), rgb(255, 255, 255), rgb(255, 140, 220) },
		premiumLook = true,
		style = { pieces = 16, spread = 45, speed = 22, ring = true, stars = true },
	},

	-- Accessories: visuals only. Bonus values and IDs are A's (proposed IDs, see CONTRACT_REQUESTS).
	{
		id = "accessory.zoom_sneakers",
		slot = "Accessory",
		nameKey = "item.accessory.zoom_sneakers",
		icon = "shoe",
		colors = { rgb(255, 90, 90), rgb(255, 255, 255) },
		premiumLook = false,
		style = { attach = "feet" },
	},
	{
		id = "accessory.focus_goggles",
		slot = "Accessory",
		nameKey = "item.accessory.focus_goggles",
		icon = "goggles",
		colors = { rgb(90, 200, 255), rgb(40, 40, 60) },
		premiumLook = false,
		style = { attach = "head" },
	},
	{
		id = "accessory.sharp_glove",
		slot = "Accessory",
		nameKey = "item.accessory.sharp_glove",
		icon = "glove",
		colors = { rgb(255, 210, 80), rgb(255, 255, 255) },
		premiumLook = false,
		style = { attach = "hand" },
	},

	-- Consumables
	{
		id = "consumable.skip_token",
		slot = "Consumable",
		nameKey = "item.consumable.skip_token",
		descKey = "item.consumable.skip_token.desc",
		icon = "skip",
		colors = { rgb(120, 200, 255), rgb(255, 255, 255) },
		premiumLook = false,
		style = {},
	},
	{
		id = "consumable.double_xp",
		slot = "Consumable",
		nameKey = "item.consumable.double_xp",
		descKey = "item.consumable.double_xp.desc",
		icon = "xp",
		colors = { rgb(140, 110, 255), rgb(255, 230, 90) },
		premiumLook = false,
		style = {},
	},
}

local BY_ID: { [string]: VisualDescriptor } = {}
for _, d in LIST do
	assert(BY_ID[d.id] == nil, "duplicate visual id " .. d.id)
	BY_ID[d.id] = d
end

local FALLBACK: VisualDescriptor = {
	id = "unknown",
	slot = "Accessory",
	nameKey = "item.unknown",
	icon = "question",
	colors = { rgb(200, 200, 200) },
	premiumLook = false,
	style = {},
}

return {
	LIST = LIST,
	BY_ID = BY_ID,
	-- Unknown IDs (e.g. A added an item before B made art) get a neutral placeholder, never an error.
	get = function(id: string): VisualDescriptor
		return BY_ID[id] or FALLBACK
	end,
	has = function(id: string): boolean
		return BY_ID[id] ~= nil
	end,
}
