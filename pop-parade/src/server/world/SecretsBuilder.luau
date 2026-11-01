--!strict
-- SERVER-ONLY: builds the three golden secrets, their hiding places and subtle clues.
-- Positions come from SecretsLayout (server-only). Golden balloons are world props; discovery is
-- detected and granted by A's server systems using the manifest's private SecretDefs.

local Geometry = require(script.Parent.Geometry)
local SecretsLayout = require(script.Parent.SecretsLayout)

local SecretsBuilder = {}

local WHITE = { r = 1, g = 1, b = 1 }
local ROCK = { r = 0.62, g = 0.52, b = 0.72 } -- candy-rock lilac
local SODA = { r = 0.55, g = 0.85, b = 1.0 }

local function goldenBalloon(Content: any, parent: Instance, name: string, pos: Vector3): Model
	local m = Geometry.model(parent, name)
	local body = Geometry.ball(m, "Body", pos, 3.6, Content.Branding.golden, { canCollide = false, material = "SmoothPlastic", reflectance = 0.3 })
	Geometry.part(m, "Knot", Vector3.new(0.7, 0.7, 0.7), CFrame.new(pos - Vector3.new(0, 1.95, 0)) * CFrame.Angles(0, 0, math.rad(45)), { r = 0.9, g = 0.7, b = 0.1 }, { canCollide = false })
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 230, 120)
	sparkle.Parent = body
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 90)
	light.Range = 8
	light.Brightness = 1.2
	light.Parent = body
	m.PrimaryPart = body
	return m
end

function SecretsBuilder.build(Content: any, rubberLayout: any, parent: Instance): { [string]: Model }
	local Palette = Content.Palette
	local folder = Geometry.folder(parent, "Landmarks") -- neutral name on purpose
	local placements = SecretsLayout.placements(rubberLayout)
	local byId: { [string]: any } = {}
	for _, s in placements do
		byId[s.id] = s
	end
	local balloons: { [string]: Model } = {}

	------------------------------------------------------------------ Fizzy Falls (hub NE)
	do
		local f = SecretsLayout.FALLS
		local m = Geometry.model(folder, "FizzyFalls")
		local zc, half = f.wallZ, 3
		-- wall left/right of the opening + lintel above it
		local function wallSeg(x0: number, x1: number, y0: number, y1: number)
			Geometry.part(m, "Rock", Vector3.new(x1 - x0, y1 - y0, 6), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, zc), ROCK, { material = "Slate" })
		end
		wallSeg(f.wallMinX, f.openMinX, 0, f.height)
		wallSeg(f.openMaxX, f.wallMaxX, 0, f.height)
		wallSeg(f.openMinX, f.openMaxX, f.openHeight, f.height)
		-- cave behind the opening
		local back = f.caveBackZ
		local caveMinX, caveMaxX = f.openMinX - 2, f.openMaxX + 2
		Geometry.part(m, "Rock", Vector3.new(caveMaxX - caveMinX + 2, 11, 2), CFrame.new((caveMinX + caveMaxX) / 2, 5.5, back - 1), ROCK, { material = "Slate" })
		for _, x in { caveMinX - 1, caveMaxX + 1 } do
			Geometry.part(m, "Rock", Vector3.new(2, 11, zc - half - back), CFrame.new(x, 5.5, (zc - half + back) / 2), ROCK, { material = "Slate" })
		end
		Geometry.part(m, "Rock", Vector3.new(caveMaxX - caveMinX + 4, 2, zc - half - back + 2), CFrame.new((caveMinX + caveMaxX) / 2, 11, (zc - half + back) / 2), ROCK, { material = "Slate" })
		-- boulders on top for a natural silhouette
		for i = 0, 4 do
			Geometry.ball(m, "Boulder", Vector3.new(f.wallMinX + 3 + i * 6, f.height + 1.5, zc), 7 + (i % 2) * 2, Palette.mix(ROCK, WHITE, 0.1), { material = "Slate" })
		end
		-- the falls: translucent soda curtain in front of the opening (walk-through)
		local width = f.openMaxX - f.openMinX + 4
		local fall = Geometry.part(m, "Falls", Vector3.new(width, f.height, 0.6), CFrame.new((f.openMinX + f.openMaxX) / 2, f.height / 2, zc + half + 0.4), SODA, { material = "Glass", transparency = 0.45, canCollide = false, castShadow = false })
		local fizz = Instance.new("ParticleEmitter")
		fizz.Rate = 6
		fizz.Lifetime = NumberRange.new(1, 1.6)
		fizz.Speed = NumberRange.new(2, 4)
		fizz.SpreadAngle = Vector2.new(20, 20)
		fizz.Size = NumberSequence.new(0.35)
		fizz.Transparency = NumberSequence.new(0.3)
		fizz.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
		fizz.Parent = fall
		Geometry.disk(m, "Pool", (f.openMinX + f.openMaxX) / 2, 0.15, zc + 8, 7, 0.1, SODA, { material = "Glass", transparency = 0.35, canCollide = false })
		-- CLUE: a trail of fizzy bubbles on the ground leading INTO the falls
		for i = 0, 6 do
			local p = Vector3.new(f.openMinX - 14 + i * 2.6, 0.35, zc + 10 - i * 1.4)
			Geometry.ball(m, "Bubble", p, 0.7 - i * 0.04, Palette.mix(SODA, WHITE, 0.5), { transparency = 0.25, canCollide = false, castShadow = false })
		end
		local s = byId["secret.rubber.waterfall"]
		balloons[s.id] = goldenBalloon(Content, m, "Ornament", Geometry.v3(s.pos))
	end

	------------------------------------------------------------------ Big Top tent (hub SW)
	do
		local t = SecretsLayout.TENT
		local m = Geometry.model(folder, "BigTop")
		local c = t.center
		local red = { r = 0.95, g = 0.3, b = 0.35 }
		local stripes = 16
		for i = 0, stripes - 1 do
			local a = (i / stripes) * math.pi * 2
			-- doorway: skip the two stripes facing the plaza centre (north-east)
			local isDoor = i == 13 or i == 14
			if not isDoor then
				local pos = Vector3.new(c.x + math.cos(a) * t.wallRadius, t.wallHeight / 2, c.z + math.sin(a) * t.wallRadius)
				Geometry.part(m, "Wall", Vector3.new(4.05, t.wallHeight, 0.8), CFrame.lookAt(pos, Vector3.new(c.x, t.wallHeight / 2, c.z)), if i % 2 == 0 then red else WHITE)
			end
		end
		for k, layer in SecretsLayout.tentLayers() do
			Geometry.disk(m, "Roof", c.x, layer.top, c.z, layer.radius, t.layerRise, if k % 2 == 0 then WHITE else red)
		end
		local layers = SecretsLayout.tentLayers()
		local capTop = layers[#layers].top
		Geometry.column(m, "FlagPole", c.x + 1.5, capTop, c.z, 0.15, 7, WHITE, { canCollide = false })
		Geometry.part(m, "Flag", Vector3.new(0.15, 1.6, 2.6), CFrame.new(c.x + 1.5, capTop + 6.2, c.z + 1.3), Content.Branding.golden, { canCollide = false })
		-- crate stair (columns of 1, 2, 3 crates)
		for i, base in t.crates do
			for k = 1, i do
				Geometry.part(m, "Crate", Vector3.new(t.crateSize, t.crateSize, t.crateSize), CFrame.new(base.x, (k - 0.5) * t.crateSize, base.z), { r = 0.78, g = 0.6, b = 0.38 }, { material = "WoodPlanks" })
			end
		end
		-- CLUE: tiny gold star sticker on the lowest crate's plaza-facing side
		local first = t.crates[1]
		Geometry.part(m, "Sticker", Vector3.new(0.1, 0.9, 0.9), CFrame.new(first.x + t.crateSize / 2 + 0.05, 1.7, first.z) * CFrame.Angles(math.rad(45), 0, 0), Content.Branding.golden, { canCollide = false, castShadow = false, material = "Neon" })
		local s = byId["secret.hub.big_top"]
		balloons[s.id] = goldenBalloon(Content, m, "Ornament", Geometry.v3(s.pos))
	end

	------------------------------------------------------------------ Under the Rainbow Bridge (Rubber s2)
	do
		local m = Geometry.model(folder, "BridgeNook")
		local s = byId["secret.rubber.underbridge"]
		local pos, catchTop = SecretsLayout.underBridgeAnchor(rubberLayout)
		-- CLUE: three arrow tiles on the safety floor pointing at the bridge
		for i = 1, 3 do
			local z = pos.z + 6 + i * 4
			local cf = CFrame.new(pos.x, catchTop + 0.06, z) * CFrame.Angles(0, math.rad(45), 0)
			Geometry.part(m, "Tile", Vector3.new(2.2, 0.1, 2.2), cf, Palette.mix(Content.Themes.get("rubber").trim, WHITE, 0.2), { canCollide = false, castShadow = false })
		end
		balloons[s.id] = goldenBalloon(Content, m, "Ornament", Geometry.v3(s.pos))
	end

	return balloons
end

return SecretsBuilder
