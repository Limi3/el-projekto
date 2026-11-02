--!strict
-- Builds a stage's SHARED SOLID geometry from its layout: lanes, ramps, plazas, catch floors,
-- bridges, bonus ledges, checkpoint flags/volumes, hazard models and the boss arena.
-- It does NOT create balloons (rendered per-player on the client from A's state), does not start
-- hazard/boss behaviour (A runs those), and never touches rewards or data.

local Geometry = require(script.Parent.Geometry)

local StageBuilder = {}

export type BuiltStage = {
	model: Model,
	checkpointVolumes: { [string]: BasePart },
	hazardModels: { [string]: Model },
	arena: BasePart,
}

local LANE_STEPS = { 30, 330, 640, 820 } -- palette steps for lane:1..4 (coral, lime, sky, violet)
-- Each section shifts the lane hues so the five sections read as distinct places.
local SECTION_SHIFT = { [0] = 0, 0, 110, 230, 390, 540, 0 }
-- Section names shown on the checkpoint arch at each section's start (order 6 = boss gate).
local SECTION_NAME_KEYS = { "stage.section.1", "stage.section.2", "stage.section.3", "stage.section.4", "stage.section.5", "stage.section.boss" }

function StageBuilder.build(Content: any, layout: any, parent: Instance): BuiltStage
	local Palette = Content.Palette
	local Themes = Content.Themes
	local Strings = Content.Strings
	local theme = Themes.get(layout.theme)
	local white = { r = 1, g = 1, b = 1 }
	local function surfaceColor(key: string, section: number?): any
		if key == "floor" then
			return theme.floor
		elseif key == "trim" then
			return theme.trim
		elseif key == "accent" then
			return Palette.mix(theme.accent, white, 0.25)
		end
		local n = tonumber(string.match(key, "^lane:(%d+)$") or "")
		if n then
			local shift = SECTION_SHIFT[section or 0] or 0
			return Palette.mix(Palette.color(LANE_STEPS[((n - 1) % #LANE_STEPS) + 1] + theme.paletteOffset + shift), white, 0.35)
		end
		return theme.floor
	end

	local model = Geometry.model(parent, layout.id)
	Geometry.tag(model, { PopParadeStage = layout.id, PopParadeTheme = layout.theme })
	local floors = Geometry.folder(model, "Floors")
	local decor = Geometry.folder(model, "Decor")
	local checkpointsFolder = Geometry.folder(model, "Checkpoints")
	local hazardsFolder = Geometry.folder(model, "Hazards")

	-- Platforms
	for _, p in layout.platforms do
		local cf = Geometry.cf(p.placement.pos, p.placement.yaw, p.pitch)
		local size = Geometry.v3(p.size)
		local part = Geometry.part(floors, p.id, size, cf, surfaceColor(p.color, p.sectionIndex), { material = theme.surfaceMaterial })
		Geometry.tag(part, { PopParadeSurface = p.kind })
		-- Readable lane edges: thin trim bumpers (non-colliding) along lane/bridge sides
		if p.kind == "floor" and string.sub(p.color, 1, 5) == "lane:" then
			for side = -1, 1, 2 do
				local edge = cf * CFrame.new(side * (size.X / 2 - 0.3), size.Y / 2 + 0.2, 0)
				Geometry.part(decor, p.id .. ".edge", Vector3.new(0.6, 0.4, size.Z), edge, theme.trim, { canCollide = false, castShadow = false })
			end
		elseif p.kind == "ledge" then
			-- star marker so bonus ledges read as optional extras, not the main path
			local top = cf * CFrame.new(0, size.Y / 2, 0)
			Geometry.part(decor, p.id .. ".star", Vector3.new(size.X * 0.6, 0.12, size.Z * 0.6), top * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, math.rad(45), 0), Content.Branding.golden, { canCollide = false, castShadow = false, material = "Neon", transparency = 0.35 })
		elseif p.kind == "ramp" then
			for i = -1, 1 do
				local chevron = cf * CFrame.new(i * 8, size.Y / 2 + 0.05, 0) * CFrame.Angles(0, math.rad(45), 0)
				Geometry.part(decor, p.id .. ".chevron", Vector3.new(3, 0.1, 3), chevron, Palette.mix(theme.trim, white, 0.3), { canCollide = false, castShadow = false })
			end
		end
	end

	-- Return signs on catch floors (readable way back to missed slots)
	for _, p in layout.platforms do
		if p.color == "accent" and p.kind == "floor" and p.size.x > 40 then
			local top = p.placement.pos.y + p.size.y / 2
			local southEdge = p.placement.pos.z + p.size.z / 2
			Geometry.sign(
				decor,
				p.id .. ".returnSign",
				CFrame.new(p.placement.pos.x + 20, top + 3, southEdge - 2) * CFrame.Angles(0, math.rad(180), 0),
				Vector2.new(9, 3),
				Strings.t("stage.return_sign"),
				white,
				theme.trim
			)
		end
	end

	-- Checkpoints: flag arch for players + invisible volume for A's server-side detection
	local volumes: { [string]: BasePart } = {}
	for _, cp in layout.checkpoints do
		local pos = Geometry.v3(cp.placement.pos)
		local size = Geometry.v3(cp.size)
		local floorTop = pos.Y - size.Y / 2
		local vol = Geometry.part(checkpointsFolder, cp.id, size, CFrame.new(pos), theme.accent, {
			transparency = 1,
			canCollide = false,
			canQuery = true,
			castShadow = false,
		})
		Geometry.tag(vol, { PopParadeCheckpoint = cp.id, Order = cp.order, StageId = cp.stageId })
		volumes[cp.id] = vol
		local half = size.X / 2 + 1
		for side = -1, 1, 2 do
			Geometry.column(decor, cp.id .. ".pole", pos.X + side * half, floorTop, pos.Z, 0.4, 9, white, { canCollide = false })
			Geometry.ball(decor, cp.id .. ".cap", Vector3.new(pos.X + side * half, floorTop + 9.4, pos.Z), 1.4, theme.trim, { canCollide = false })
		end
		local banner = Geometry.part(decor, cp.id .. ".banner", Vector3.new(half * 2, 1.4, 0.3), CFrame.new(pos.X, floorTop + 8, pos.Z), theme.trim, { canCollide = false })
		Geometry.tag(banner, { PopParadeCheckpointBanner = cp.id })
		-- Landmark: section name + number above the arch, readable from the previous section
		local nameKey = SECTION_NAME_KEYS[cp.order]
		if nameKey then
			local signColor = if cp.order <= 5 then Palette.mix(Palette.color(LANE_STEPS[1] + theme.paletteOffset + (SECTION_SHIFT[cp.order] or 0)), white, 0.1) else theme.trim
			Geometry.sign(decor, cp.id .. ".name", CFrame.new(pos.X, floorTop + 10.6, pos.Z) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(half * 1.6, 2.8), Strings.t(nameKey), white, signColor)
			-- back face so it also reads when walking back to a missed balloon
			Geometry.sign(decor, cp.id .. ".nameBack", CFrame.new(pos.X, floorTop + 10.6, pos.Z - 0.35), Vector2.new(half * 1.6, 2.8), Strings.t(nameKey), white, signColor)
		end
	end

	-- Hazards: geometry + attributes only; A animates/evaluates them by ID.
	local hazardModels: { [string]: Model } = {}
	for _, h in layout.hazards do
		local m = Geometry.model(hazardsFolder, h.id)
		Geometry.tag(m, { PopParadeHazard = h.id, BehaviorKey = h.behaviorKey, CheckpointId = h.checkpointId })
		local base = Geometry.cf(h.placement.pos, h.placement.yaw)
		if h.behaviorKey == "sweeper" then
			local floorTop = h.placement.pos.y - h.params.height
			local post = Geometry.column(m, "Post", h.placement.pos.x, floorTop, h.placement.pos.z, 1, h.params.height + 0.8, theme.trim)
			local pivot = Geometry.part(m, "Pivot", Vector3.new(1, 1, 1), base, white, { transparency = 1, canCollide = false })
			local arm = Geometry.part(m, "Arm", Geometry.v3(h.shape.size), base, { r = 1, g = 0.3, b = 0.35 }, { canCollide = false })
			for side = -1, 1, 2 do
				Geometry.part(m, "ArmTip", Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(side * h.shape.size.x / 2, 0, 0), white, { canCollide = false, shape = Enum.PartType.Ball })
			end
			m.PrimaryPart = pivot
			post.CanCollide = true
			arm:SetAttribute("PopParadeHazardPart", true)
		elseif h.behaviorKey == "tack_mat" then
			local plate = Geometry.part(m, "Plate", Geometry.v3(h.shape.size), base, { r = 0.55, g = 0.56, b = 0.62 }, { material = "Metal" })
			plate:SetAttribute("PopParadeHazardPart", true)
			local sx, sz = h.shape.size.x, h.shape.size.z
			for ix = 0, 4 do
				for iz = 0, 1 do
					local off = CFrame.new(-sx / 2 + (ix + 0.5) * sx / 5, h.shape.size.y / 2 + 0.25, -sz / 2 + (iz + 0.5) * sz / 2)
					Geometry.part(m, "Tack", Vector3.new(0.5, 1.4, 1.4), base * off * CFrame.Angles(0, 0, math.rad(90)), Content.Branding.golden, { canCollide = false, shape = Enum.PartType.Cylinder, material = "Metal" })
				end
			end
			m.PrimaryPart = plate
		elseif h.behaviorKey == "puff_vent" then
			local d = h.shape.size.x
			local grate = Geometry.disk(m, "Grate", h.placement.pos.x, h.placement.pos.y + 0.2, h.placement.pos.z, d / 2, 0.4, { r = 0.3, g = 0.3, b = 0.38 }, { material = "DiamondPlate" })
			Geometry.ring(m, "Rim", Vector3.new(h.placement.pos.x, h.placement.pos.y + 0.3, h.placement.pos.z), d / 2, 10, Vector3.new(1.9, 0.5, 0.6), theme.accent, { canCollide = false })
			local nozzle = Instance.new("Attachment")
			nozzle.Name = "Nozzle"
			nozzle.Position = Vector3.new(0, 0.3, 0)
			nozzle.Parent = grate
			grate:SetAttribute("PopParadeHazardPart", true)
			m.PrimaryPart = grate
		end
		hazardModels[h.id] = m
	end

	-- Boss arena: round drum floor + low drum rim + tall striped backdrop (visible from afar)
	local boss = layout.boss
	local c = boss.arenaCenter
	local arena = Geometry.disk(model, boss.id .. ".arena", c.x, c.y, c.z, boss.arenaRadius, 2, theme.floor, { material = theme.surfaceMaterial })
	Geometry.tag(arena, { PopParadeArena = boss.id })
	Geometry.disk(decor, boss.id .. ".drumskin", c.x, c.y + 0.05, c.z, boss.arenaRadius * 0.62, 0.1, Palette.mix(theme.accent, white, 0.5), { canCollide = false, castShadow = false })
	Geometry.ring(model, "ArenaRim", Vector3.new(c.x, c.y + 1.5, c.z), boss.arenaRadius + 0.6, 36, Vector3.new(7.6, 3, 1.2), theme.trim)
	for i = 0, 8 do
		local a = math.pi + (i / 8) * math.pi -- north half
		local px, pz = c.x + math.cos(a) * (boss.arenaRadius + 4), c.z + math.sin(a) * (boss.arenaRadius + 4)
		local col = if i % 2 == 0 then theme.trim else white
		Geometry.part(decor, "Backdrop", Vector3.new(14, 34, 1.5), CFrame.lookAt(Vector3.new(px, c.y + 17, pz), Vector3.new(c.x, c.y + 17, c.z)), col, { canCollide = false })
	end
	-- anchor marker for the client-rendered King Puffer (no gameplay meaning)
	local anchor = Geometry.part(model, boss.id .. ".anchor", Vector3.new(1, 1, 1), Geometry.cf(boss.anchor.pos, boss.anchor.yaw), white, { transparency = 1, canCollide = false, canQuery = false })
	Geometry.tag(anchor, { PopParadeBossAnchor = boss.id })

	return { model = model, checkpointVolumes = volumes, hazardModels = hazardModels, arena = arena }
end

return StageBuilder
