--!strict
-- POP PARADE: 1,000-step full-spectrum palette.
-- Pure math (no Roblox APIs) so it can be unit-tested with plain Luau.
-- Hues are generated in OKLCH so brightness stays visually even across the spectrum;
-- chroma is reduced only as far as needed to stay inside sRGB.

local Palette = {}

Palette.STEPS = 1000
Palette.LIGHTNESS = 0.76 -- OKLab L; bright toy look without washing out
Palette.CHROMA = 0.16 -- target chroma before gamut clipping

export type RGB = { r: number, g: number, b: number }

local function clamp01(x: number): number
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end

local function linearToSrgb(c: number): number
	if c <= 0.0031308 then
		return 12.92 * c
	end
	return 1.055 * c ^ (1 / 2.4) - 0.055
end

local function srgbToLinear(c: number): number
	if c <= 0.04045 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end

-- OKLab -> linear sRGB (Björn Ottosson's reference matrices)
local function oklabToLinear(L: number, a: number, b: number): (number, number, number)
	local l_ = L + 0.3963377774 * a + 0.2158037573 * b
	local m_ = L - 0.1055613458 * a - 0.0638541728 * b
	local s_ = L - 0.0894841775 * a - 1.2914855480 * b
	local l, m, s = l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_
	return 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
end

local function inGamut(r: number, g: number, b: number): boolean
	local e = 1e-4
	return r >= -e and r <= 1 + e and g >= -e and g <= 1 + e and b >= -e and b <= 1 + e
end

-- Returns an sRGB colour for OKLCH(L, C, hueTurns), shrinking chroma until it fits sRGB.
function Palette.oklch(L: number, C: number, hueTurns: number): RGB
	local h = hueTurns * 2 * math.pi
	local lo, hi = 0, C
	local r, g, b = oklabToLinear(L, C * math.cos(h), C * math.sin(h))
	if not inGamut(r, g, b) then
		for _ = 1, 18 do
			local mid = (lo + hi) / 2
			local rr, gg, bb = oklabToLinear(L, mid * math.cos(h), mid * math.sin(h))
			if inGamut(rr, gg, bb) then
				lo = mid
			else
				hi = mid
			end
		end
		r, g, b = oklabToLinear(L, lo * math.cos(h), lo * math.sin(h))
	end
	return {
		r = clamp01(linearToSrgb(clamp01(r))),
		g = clamp01(linearToSrgb(clamp01(g))),
		b = clamp01(linearToSrgb(clamp01(b))),
	}
end

-- Normalises any integer (or fractional, for animation) step into [0, STEPS).
function Palette.wrap(step: number): number
	return step % Palette.STEPS
end

local cache: { [number]: RGB } = {}

-- Colour for an integer palette step (0..999). Fractional steps interpolate smoothly.
function Palette.color(step: number): RGB
	local s = Palette.wrap(step)
	local i = math.floor(s)
	local f = s - i
	local c0 = cache[i]
	if not c0 then
		c0 = Palette.oklch(Palette.LIGHTNESS, Palette.CHROMA, i / Palette.STEPS)
		cache[i] = c0
	end
	if f < 1e-6 then
		return c0
	end
	local c1 = Palette.color((i + 1) % Palette.STEPS)
	return { r = c0.r + (c1.r - c0.r) * f, g = c0.g + (c1.g - c0.g) * f, b = c0.b + (c1.b - c0.b) * f }
end

-- Even sampling along a formation: slot n of total spread across the spectrum, plus an offset.
function Palette.stepFor(index: number, total: number, offset: number?): number
	local base = math.floor(((index - 1) * Palette.STEPS) / math.max(total, 1))
	return Palette.wrap(base + (offset or 0))
end

-- Relative luminance (WCAG) of an sRGB colour.
function Palette.luminance(c: RGB): number
	return 0.2126 * srgbToLinear(c.r) + 0.7152 * srgbToLinear(c.g) + 0.0722 * srgbToLinear(c.b)
end

function Palette.mix(a: RGB, b: RGB, t: number): RGB
	return { r = a.r + (b.r - a.r) * t, g = a.g + (b.g - a.g) * t, b = a.b + (b.b - a.b) * t }
end

function Palette.desaturate(c: RGB, amount: number): RGB
	local y = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return Palette.mix(c, { r = y, g = y, b = y }, amount)
end

return Palette
