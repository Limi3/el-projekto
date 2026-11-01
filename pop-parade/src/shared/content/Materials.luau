--!strict
-- Material and theme treatments for balloons and world surfaces.
-- Pure data/math; Roblox Enum names are stored as strings and resolved by renderers.
-- Every material supports the full 1,000-step palette while keeping its identity
-- (wood grain, metal highlights, crystal facets, gold frames).

local Palette = require(script.Parent.Palette)

local Materials = {}

export type Treatment = {
	body: Palette.RGB,
	frame: Palette.RGB?, -- trim/knot/frame colour; nil = derived from body
	robloxMaterial: string, -- Enum.Material name
	transparency: number,
	reflectance: number,
	detail: string, -- visual detail kind the renderer adds: "shine" | "grain" | "bands" | "frame" | "facets"
}

export type MaterialInfo = {
	key: string,
	displayKey: string, -- Strings key
	order: number,
	status: "playable" | "planned",
	tint: number, -- how much of the palette survives (0..1)
	robloxMaterial: string,
	transparency: number,
	reflectance: number,
	detail: string,
	frame: Palette.RGB?,
}

local GOLD: Palette.RGB = { r = 1.0, g = 0.80, b = 0.25 }

-- Main progression order: Rubber -> Wood -> Steel -> Gold -> Diamond.
Materials.ORDER = { "rubber", "wood", "steel", "gold", "diamond" }

Materials.INFO = {
	rubber = {
		key = "rubber",
		displayKey = "material.rubber",
		order = 1,
		status = "playable",
		tint = 1.0,
		robloxMaterial = "SmoothPlastic",
		transparency = 0,
		reflectance = 0.05,
		detail = "shine",
	},
	wood = {
		key = "wood",
		displayKey = "material.wood",
		order = 2,
		status = "planned",
		tint = 0.55,
		robloxMaterial = "Wood",
		transparency = 0,
		reflectance = 0,
		detail = "grain",
	},
	steel = {
		key = "steel",
		displayKey = "material.steel",
		order = 3,
		status = "planned",
		tint = 0.45,
		robloxMaterial = "Metal",
		transparency = 0,
		reflectance = 0.25,
		detail = "bands",
	},
	gold = {
		key = "gold",
		displayKey = "material.gold",
		order = 4,
		status = "planned",
		tint = 0.8, -- rainbow-tinted body inside a gold frame
		robloxMaterial = "SmoothPlastic",
		transparency = 0,
		reflectance = 0.2,
		detail = "frame",
		frame = GOLD,
	},
	diamond = {
		key = "diamond",
		displayKey = "material.diamond",
		order = 5,
		status = "planned",
		tint = 0.6,
		robloxMaterial = "Glass",
		transparency = 0.25,
		reflectance = 0.3,
		detail = "facets",
	},
} :: { [string]: MaterialInfo }

local WOOD_BASE: Palette.RGB = { r = 0.62, g = 0.42, b = 0.25 }
local STEEL_BASE: Palette.RGB = { r = 0.70, g = 0.73, b = 0.78 }
local WHITE: Palette.RGB = { r = 1, g = 1, b = 1 }

-- Treatment for a material at a palette step. Unknown keys fall back to rubber.
function Materials.treatment(materialKey: string, step: number): Treatment
	local info = Materials.INFO[materialKey] or Materials.INFO.rubber
	local hue = Palette.color(step)
	local body: Palette.RGB
	if info.key == "wood" then
		body = Palette.mix(WOOD_BASE, hue, info.tint)
	elseif info.key == "steel" then
		body = Palette.mix(STEEL_BASE, hue, info.tint)
	elseif info.key == "diamond" then
		body = Palette.mix(WHITE, hue, info.tint)
	else
		body = Palette.mix(WHITE, hue, info.tint)
	end
	local frame = info.frame or Palette.mix(body, { r = 0, g = 0, b = 0 }, 0.25)
	return {
		body = body,
		frame = frame,
		robloxMaterial = info.robloxMaterial,
		transparency = info.transparency,
		reflectance = info.reflectance,
		detail = info.detail,
	}
end

return Materials
