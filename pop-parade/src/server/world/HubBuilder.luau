--!strict
-- Builds the hub plaza ("Pop Plaza"): bright toy/carnival style with strong silhouettes.
-- Layout positions come from Content.Layouts.Hub; this file adds the look.
-- Markers get attributes so the client can show contextual hints (PopParadeMarker/Kind).
-- Nothing here grants rewards, opens purchases or runs gameplay.

local Geometry = require(script.Parent.Geometry)

local HubBuilder = {}

export type BuiltHub = { model: Model, spawn: SpawnLocation, markerModels: { [string]: Model } }

local WHITE = { r = 1, g = 1, b = 1 }

function HubBuilder.build(Content: any, parent: Instance): BuiltHub
	local Palette = Content.Palette
	local Strings = Content.Strings
	local Branding = Content.Branding
	local theme = Content.Themes.get("hub")
	local hub = Content.Layouts.Hub.get()
	local H = Content.Layouts.Hub

	local model = Geometry.model(parent, "Hub")
	local ground = Geometry.folder(model, "Ground")
	local decor = Geometry.folder(model, "Decor")
	local stations = Geometry.folder(model, "Stations")

	local function hue(step: number, whiteMix: number?): any
		return Palette.mix(Palette.color(step), WHITE, whiteMix or 0)
	end

	-- Ground: big cream disk, pink inner ring, checkerboard promenade spawn -> stage gate
	Geometry.disk(ground, "Plaza", 0, 0, 0, H.PLAZA_RADIUS, 4, theme.floor)
	Geometry.disk(ground, "PlazaBand", 0, 0.08, 0, H.PLAZA_RADIUS - 3, 0.1, Palette.mix(theme.floor, theme.trim, 0.25), { canCollide = false, castShadow = false })
	Geometry.disk(ground, "PlazaInner", 0, 0.12, 0, H.PLAZA_RADIUS - 6, 0.1, theme.floor, { canCollide = false, castShadow = false })
	Geometry.disk(ground, "CenterRing", 0, 0.16, -10, 22, 0.1, Palette.mix(theme.trim, WHITE, 0.45), { canCollide = false, castShadow = false })
	local tile = 0
	for z = 62, H.STAGE_GATE_Z + 4, -8 do
		tile += 1
		for xi = -1, 1 do
			local even = (tile + xi) % 2 == 0
			Geometry.part(ground, "PathTile", Vector3.new(8, 0.1, 8), CFrame.new(xi * 8, 0.2, z), if even then WHITE else Palette.mix(theme.accent, WHITE, 0.35), { canCollide = false, castShadow = false })
		end
	end

	-- Spawn: real SpawnLocation (Neutral) facing the practice balloons
	local sp = hub.spawn
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "PopParadeSpawn"
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Duration = 0
	spawnLoc.Size = Vector3.new(10, 1, 10)
	spawnLoc.CFrame = Geometry.cf({ x = sp.pos.x, y = 0.5, z = sp.pos.z }, sp.yaw)
	spawnLoc.Color = Geometry.toColor3(theme.trim)
	spawnLoc.Material = Enum.Material.SmoothPlastic
	spawnLoc.TopSurface = Enum.SurfaceType.Smooth
	spawnLoc.Parent = model
	local decal = spawnLoc:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	Geometry.ring(decor, "SpawnRing", Vector3.new(sp.pos.x, 0.6, sp.pos.z), 6.5, 16, Vector3.new(2.4, 0.4, 0.6), WHITE, { canCollide = false })

	-- Balloon arch over the promenade (pure decoration, not poppable)
	for i = 0, 16 do
		local a = (i / 16) * math.pi
		local pos = Vector3.new(math.cos(a) * 14, math.sin(a) * 14 + 0.5, 4)
		Geometry.ball(decor, "ArchBalloon", pos, 3.2, hue(i * 60, 0.15), { canCollide = false, reflectance = 0.05 })
	end

	-- Helper: classic carnival booth (counter + striped canopy + sign)
	local function booth(parentFolder: Instance, name: string, cf: CFrame, colorA: any, label: string, width: number?): Model
		local w = width or 10
		local m = Geometry.model(parentFolder, name)
		Geometry.part(m, "Counter", Vector3.new(w, 3.2, 4), cf * CFrame.new(0, 1.6, 0), WHITE)
		Geometry.part(m, "CounterTrim", Vector3.new(w + 0.4, 0.6, 4.4), cf * CFrame.new(0, 3.3, 0), colorA)
		for side = -1, 1, 2 do
			Geometry.column(m, "Post", (cf * CFrame.new(side * (w / 2 - 0.5), 0, 1.5)).Position.X, 0, (cf * CFrame.new(side * (w / 2 - 0.5), 0, 1.5)).Position.Z, 0.35, 9, colorA)
		end
		local stripes = 6
		for i = 0, stripes - 1 do
			local x = -w / 2 + (i + 0.5) * (w / stripes)
			Geometry.part(m, "Canopy", Vector3.new(w / stripes + 0.02, 0.5, 6.5), cf * CFrame.new(x, 9.3, 0.5) * CFrame.Angles(math.rad(-12), 0, 0), if i % 2 == 0 then colorA else WHITE)
		end
		Geometry.sign(m, "Sign", cf * CFrame.new(0, 11.2, 1.2) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(w * 0.9, 2.4), label, WHITE, colorA)
		return m
	end

	local markerModels: { [string]: Model } = {}

	-- Markers
	for _, mk in hub.markers do
		local cf = Geometry.cf(mk.placement.pos, mk.placement.yaw)
		local m: Model
		if mk.kind == "kiosk.upgrades" then
			local upgradeId = mk.data.upgradeId
			local col = Branding.upgrade[upgradeId]
			-- booth front faces the plaza; the canopy sign reads the upgrade name
			m = booth(stations, mk.id, cf * CFrame.Angles(0, math.rad(180), 0), col, string.upper(Strings.t("upgrade." .. upgradeId)), 9)
			Geometry.ball(m, "Topper", (cf * CFrame.new(0, 14, 0)).Position, 3, col, { canCollide = false })
		elseif mk.kind == "display.cosmetics" then
			m = Geometry.model(stations, mk.id)
			local base = cf.Position
			Geometry.column(m, "Pedestal", base.X, 0, base.Z, 2.6, 3, WHITE)
			Geometry.column(m, "PedestalTrim", base.X, 3, base.Z, 2.9, 0.5, theme.trim)
			Geometry.part(m, "Case", Vector3.new(4.5, 6, 4.5), CFrame.new(base + Vector3.new(0, 6.6, 0)), WHITE, { material = "Glass", transparency = 0.7, canCollide = false })
			local slot = Instance.new("Attachment")
			slot.Name = "DisplaySlot"
			slot.Parent = Geometry.part(m, "DisplayAnchor", Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(0, 6.5, 0)), WHITE, { transparency = 1, canCollide = false })
			local desc = Content.VisualCatalog.get(mk.data.itemId)
			Geometry.sign(m, "Label", cf * CFrame.new(0, 1.6, -2.75), Vector2.new(5, 1.4), Strings.t(desc.nameKey), WHITE, theme.trim)
		elseif mk.kind == "wheel" then
			m = Geometry.model(stations, mk.id)
			local center = cf * CFrame.new(0, 12, 0)
			for side = -1, 1, 2 do
				Geometry.part(m, "Leg", Vector3.new(1, 13, 1), center * CFrame.new(side * 4, -6, 1.5) * CFrame.Angles(0, 0, math.rad(side * 15)), theme.trim)
			end
			local segs = 10
			for i = 0, segs - 1 do
				local a = (i / segs) * math.pi * 2
				Geometry.part(m, "Spoke", Vector3.new(1.4, 9, 0.6), center * CFrame.Angles(0, 0, a) * CFrame.new(0, 4.5, 0), hue(i * 100, 0.1), { canCollide = false })
			end
			for i = 0, 23 do
				local a = (i / 24) * math.pi * 2
				Geometry.part(m, "Rim", Vector3.new(2.6, 0.8, 0.9), center * CFrame.Angles(0, 0, a) * CFrame.new(0, 9.2, 0), if i % 2 == 0 then WHITE else theme.trim, { canCollide = false })
			end
			Geometry.ball(m, "Hub", center.Position, 2.4, Branding.golden, { canCollide = false })
			Geometry.part(m, "Pointer", Vector3.new(1.2, 2.4, 1.2), center * CFrame.new(0, 10.8, 0.6) * CFrame.Angles(0, 0, math.rad(45)), WHITE, { canCollide = false })
			Geometry.sign(m, "Sign", cf * CFrame.new(0, 2.5, -3), Vector2.new(10, 2.4), Strings.t("hub.sign.wheel"), WHITE, Branding.currency.Tickets)
		elseif mk.kind == "rewards" then
			m = booth(stations, mk.id, cf * CFrame.Angles(0, math.rad(180), 0), Branding.currency.Coins, Strings.t("hub.sign.rewards"), 12)
			for i = 0, 4 do
				local s = 2 + (i % 3) * 0.6
				local p = (cf * CFrame.new(-4 + i * 2, s / 2, -4)).Position
				Geometry.part(m, "Gift", Vector3.new(s, s, s), CFrame.new(p) * CFrame.Angles(0, i * 0.4, 0), hue(i * 170 + 50, 0.1))
				Geometry.part(m, "Ribbon", Vector3.new(s + 0.05, s + 0.05, 0.4), CFrame.new(p) * CFrame.Angles(0, i * 0.4, 0), WHITE, { canCollide = false })
			end
		elseif mk.kind == "gate.stage" then
			m = Geometry.model(stations, mk.id)
			local gz = mk.placement.pos.z
			for side = -1, 1, 2 do
				for k = 0, 5 do
					Geometry.part(m, "Pillar", Vector3.new(4, 3, 4), CFrame.new(side * 13, 1.5 + k * 3, gz), if k % 2 == 0 then theme.trim else WHITE)
				end
				Geometry.ball(m, "PillarCap", Vector3.new(side * 13, 19.5, gz), 4.5, Branding.golden)
			end
			Geometry.part(m, "Lintel", Vector3.new(30, 3, 4), CFrame.new(0, 19, gz), theme.trim)
			Geometry.sign(m, "Sign", CFrame.new(0, 19, gz + 2.1) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(22, 2.6), Strings.t("hub.sign.stage"), WHITE, theme.trim)
			-- aspirational boss preview: a giant King Puffer silhouette balloon on top of the gate
			Geometry.ball(m, "PufferPreview", Vector3.new(0, 30, gz - 2), 14, { r = 1, g = 0.45, b = 0.6 }, { canCollide = false })
			Geometry.part(m, "PufferKnot", Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 22.6, gz - 2) * CFrame.Angles(0, 0, math.rad(45)), { r = 0.85, g = 0.3, b = 0.45 }, { canCollide = false })
			Geometry.part(m, "PufferCrown", Vector3.new(6, 2.4, 6), CFrame.new(0, 37.5, gz - 2), Branding.golden, { canCollide = false })
			-- walkway from the plaza edge to the stage entrance plaza (z = -110)
			Geometry.part(ground, "StageWalkway", Vector3.new(22, 2, 16), CFrame.new(0, -1, gz - 4), theme.floor)
		elseif mk.kind == "gate.parkour" then
			m = Geometry.model(stations, mk.id)
			local p = mk.placement.pos
			for side = -1, 1, 2 do
				Geometry.column(m, "Post", p.x, 0, p.z + side * 6, 0.8, 12, if side < 0 then theme.accent else theme.trim)
			end
			-- ribbon arch
			for i = 0, 8 do
				local a = (i / 8) * math.pi
				Geometry.part(m, "Ribbon", Vector3.new(1, 1.2, 2.2), CFrame.new(p.x, 12 + math.sin(a) * 3, p.z + math.cos(a) * 6), hue(i * 110, 0.1), { canCollide = false })
			end
			Geometry.sign(m, "Sign", CFrame.new(p.x - 0.5, 16.5, p.z) * CFrame.Angles(0, math.rad(-90), 0), Vector2.new(11, 3), Strings.t("hub.sign.parkour"), WHITE, theme.accent)
			Geometry.part(ground, "ParkourWalkway", Vector3.new(30, 2, 10), CFrame.new(-94, -1, p.z), theme.floor)
		elseif mk.kind == "sign" then
			m = Geometry.model(stations, mk.id)
			local p = mk.placement.pos
			Geometry.column(m, "Post", p.x, 0, p.z, 0.4, 6, { r = 0.6, g = 0.42, b = 0.25 })
			Geometry.sign(m, "Board", CFrame.new(p.x, 6, p.z) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(8, 3.4), Strings.t(mk.data.textKey), { r = 0.85, g = 0.68, b = 0.45 }, { r = 0.35, g = 0.22, b = 0.12 })
		else
			m = Geometry.model(stations, mk.id)
		end
		Geometry.tag(m, { PopParadeMarker = mk.id, Kind = mk.kind, Radius = mk.radius })
		if mk.data then
			for k, val in mk.data do
				m:SetAttribute(k, val)
			end
		end
		markerModels[mk.id] = m
	end

	-- AFK garden: hedges + free stations + premium gazebo with honest labels
	local garden = Geometry.model(stations, "AfkGarden")
	Geometry.part(garden, "Hedge", Vector3.new(50, 3, 2), CFrame.new(60, 1.5, 88), { r = 0.35, g = 0.75, b = 0.4 })
	Geometry.part(garden, "Hedge", Vector3.new(2, 3, 40), CFrame.new(34, 1.5, 70), { r = 0.35, g = 0.75, b = 0.4 })
	Geometry.sign(garden, "GardenSign", CFrame.new(34, 5, 52) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(9, 2.4), Strings.t("hub.sign.afk"), WHITE, { r = 0.3, g = 0.6, b = 0.35 })
	for _, st in hub.afk do
		local p = st.placement.pos
		local premium = st.tier == "premium"
		local col = if premium then Branding.golden else { r = 0.45, g = 0.8, b = 0.5 }
		local pad = Geometry.disk(garden, st.id, p.x, 0.3, p.z, st.radius, 0.3, col)
		Geometry.tag(pad, { PopParadeAfkStation = st.id, Tier = st.tier })
		local bp = st.balloonPos
		Geometry.column(garden, st.id .. ".tether", bp.x, 0, bp.z, 0.15, bp.y - 3, WHITE, { canCollide = false })
		local anchor = Geometry.part(garden, st.id .. ".balloonAnchor", Vector3.new(1, 1, 1), CFrame.new(bp.x, bp.y, bp.z), WHITE, { transparency = 1, canCollide = false, canQuery = false })
		Geometry.tag(anchor, { PopParadeAfkBalloon = st.id, Tier = st.tier })
		local labelKey = if premium then "afk.label_premium" else "afk.label_free"
		Geometry.sign(garden, st.id .. ".label", CFrame.new(p.x, 3, p.z + st.radius + 0.5) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(9, 2), Strings.t(labelKey), WHITE, if premium then { r = 0.6, g = 0.45, b = 0.05 } else { r = 0.25, g = 0.5, b = 0.3 })
		if premium then
			for k = 0, 5 do
				local a = (k / 6) * math.pi * 2
				Geometry.column(garden, "GazeboPost", p.x + math.cos(a) * (st.radius + 1), 0, p.z + math.sin(a) * (st.radius + 1), 0.4, 14, WHITE)
			end
			Geometry.disk(garden, "GazeboRoof", p.x, 14.6, p.z, st.radius + 2.5, 0.6, Branding.golden, { canCollide = false })
			Geometry.sign(garden, "PremiumSign", CFrame.new(p.x, 16.5, p.z + st.radius + 2) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(10, 2.2), Strings.t("hub.sign.afk_premium"), WHITE, { r = 0.6, g = 0.45, b = 0.05 })
		end
	end

	-- Perimeter: balloon posts with gaps at the two gates (no blocking rails)
	for i = 0, 47 do
		local a = (i / 48) * math.pi * 2
		local x, z = math.cos(a) * (H.PLAZA_RADIUS - 1.5), math.sin(a) * (H.PLAZA_RADIUS - 1.5)
		local nearStageGate = math.abs(x) < 16 and z < 0
		local nearParkourGate = x < 0 and math.abs(z - H.PARKOUR_GATE.pos.z) < 10
		if not nearStageGate and not nearParkourGate then
			Geometry.column(decor, "FencePost", x, 0, z, 0.35, 4, WHITE, { canCollide = false })
			Geometry.ball(decor, "FenceBalloon", Vector3.new(x, 4.8, z), 1.8, hue(i * 21, 0.15), { canCollide = false })
		end
	end

	-- Lollipop trees for silhouette and height variety
	local trees = { { -80, -60 }, { -75, 30 }, { 80, 20 }, { 20, 85 }, { -60, -85 }, { 85, -10 }, { 12, -60 }, { -12, -60 } }
	for i, t in trees do
		local h = 10 + (i % 3) * 3
		Geometry.column(decor, "TreeStick", t[1], 0, t[2], 0.5, h, WHITE, { canCollide = false })
		Geometry.ball(decor, "TreeTop", Vector3.new(t[1], h + 2.5, t[2]), 6, hue(i * 125 + 40, 0.2))
	end

	return { model = model, spawn = spawnLoc, markerModels = markerModels }
end

-- Bright, soft carnival lighting. Optional: A's bootstrap decides whether to call it.
function HubBuilder.applyLighting(Content: any, lighting: Lighting)
	local theme = Content.Themes.get("hub")
	lighting.Brightness = 2.4
	lighting.ClockTime = 14.5
	lighting.GeographicLatitude = 30
	lighting.EnvironmentDiffuseScale = 0.6
	lighting.EnvironmentSpecularScale = 0.4
	lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 190)
	lighting.Ambient = Color3.fromRGB(110, 100, 130)
	lighting.ShadowSoftness = 0.35
	local atmosphere = lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.2
	atmosphere.Color = Geometry.toColor3(theme.sky.horizon)
	atmosphere.Decay = Geometry.toColor3(theme.sky.top)
	atmosphere.Parent = lighting
	local cc = lighting:FindFirstChild("PopParadeColor") :: ColorCorrectionEffect? or Instance.new("ColorCorrectionEffect")
	cc.Name = "PopParadeColor"
	cc.Saturation = 0.12
	cc.Contrast = 0.05
	cc.Parent = lighting
end

return HubBuilder
