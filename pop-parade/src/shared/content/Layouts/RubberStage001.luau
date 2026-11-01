--!strict
-- Rubber stage 001: 100 required balloon slots + King Puffer arena.
-- Pure deterministic layout data (no Roblox APIs). WorldBuilder turns this into Parts + manifest.
--
-- Coordinate frame: hub centre is the origin, "forward" is -Z (north), floor tops at y = 0 in the hub.
-- Movement budget used for every required jump (base kit, no wings):
--   WalkSpeed 16, JumpHeight ~7.2 -> safe horizontal gap <= 4 studs, safe rise <= 4 studs.
-- Required path: every lane is walkable in both directions and every multi-lane section has a
-- catch floor 7 studs below that leads back (one 2-stud step) to the previous checkpoint plaza,
-- so a missed required slot is always recoverable without paid items.

local Palette = require(script.Parent.Parent.Palette)
local Types = require(script.Parent.Parent.ContentTypes)

type Vec3 = Types.Vec3
type StageLayout = Types.StageLayout
type PlatformLayout = Types.PlatformLayout
type BalloonLayout = Types.BalloonLayout

local STAGE_ID = "stage.rubber.001"
local THEME = "rubber"
local MATERIAL = "rubber"

local THICK = 2
local SECTION_LEN = 80
local PLAZA_LEN = 20
local RAMP_LEN = 24
local RISE = 5 -- per section joint (ramp, walkable)
local LANE_W = 10
local BALLOON_LIFT = 4.5 -- balloon centre above the lane floor top
local HIT_RADIUS = 2.6
local RESPAWN = 4
local ENTRANCE_Z = -110 -- southern edge of the stage entrance plaza (hub gate)

type LaneSpec = { name: string, x: number, width: number, count: number }
type SectionSpec = {
	lanes: { LaneSpec },
	tier: string,
	bridges: { number }?, -- z offsets (from section start) of lane-to-lane bridges
	gaps: { number }?, -- z offsets of 3-stud jump gaps cut into every lane
	hazards: { { kind: string, lane: string, at: number } }?,
}

-- 20 + 20 + 20 + 20 + 20 = 100 required slots
local SECTIONS: { SectionSpec } = {
	{ -- 1: gentle intro, one wide lane, no hazards
		lanes = { { name = "single", x = 0, width = 24, count = 20 } },
		tier = "rubber.t1",
	},
	{ -- 2: first branch, two lanes with two crossing bridges
		lanes = {
			{ name = "left", x = -7, width = LANE_W, count = 10 },
			{ name = "right", x = 7, width = LANE_W, count = 10 },
		},
		tier = "rubber.t1",
		bridges = { 25, 55 },
	},
	{ -- 3: three lanes, first obstacles (sweeper on centre, tack mats on the sides)
		lanes = {
			{ name = "left", x = -14, width = LANE_W, count = 7 },
			{ name = "center", x = 0, width = LANE_W, count = 6 },
			{ name = "right", x = 14, width = LANE_W, count = 7 },
		},
		tier = "rubber.t2",
		bridges = { 12, 68 },
		hazards = {
			{ kind = "sweeper", lane = "center", at = 40 },
			{ kind = "tack_mat", lane = "left", at = 30 },
			{ kind = "tack_mat", lane = "right", at = 52 },
		},
	},
	{ -- 4: two lanes with small 3-stud jump gaps and a mid bridge
		lanes = {
			{ name = "left", x = -7, width = LANE_W, count = 10 },
			{ name = "right", x = 7, width = LANE_W, count = 10 },
		},
		tier = "rubber.t2",
		bridges = { 40 },
		gaps = { 20, 60 },
	},
	{ -- 5: three lanes with timed puff vents, converging on the boss gate
		lanes = {
			{ name = "left", x = -14, width = LANE_W, count = 7 },
			{ name = "center", x = 0, width = LANE_W, count = 6 },
			{ name = "right", x = 14, width = LANE_W, count = 7 },
		},
		tier = "rubber.t3",
		bridges = { 15, 45 },
		hazards = {
			{ kind = "puff_vent", lane = "center", at = 25 },
			{ kind = "puff_vent", lane = "right", at = 42 },
			{ kind = "puff_vent", lane = "left", at = 58 },
		},
	},
}

local GAP = 3

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function pad(n: number, width: number): string
	local s = tostring(n)
	while #s < width do
		s = "0" .. s
	end
	return s
end

local function build(): StageLayout
	local platforms: { PlatformLayout } = {}
	local balloons: { BalloonLayout } = {}
	local routes: { Types.RouteLayout } = {}
	local checkpoints: { Types.CheckpointLayout } = {}
	local hazards: { Types.HazardLayout } = {}
	local required: { string } = {}
	local platformCount = 0
	local slot = 0
	local bonus = 0

	local function addPlatform(kind: any, cx: number, top: number, cz: number, sx: number, sz: number, color: string, section: number?, pitch: number?)
		platformCount += 1
		local cy = top - THICK / 2
		if pitch then
			cy = top - (THICK / 2) * math.cos(math.rad(pitch))
		end
		table.insert(platforms, {
			id = STAGE_ID .. ".plat." .. pad(platformCount, 3),
			kind = kind,
			placement = { pos = v(cx, cy, cz), yaw = 0 },
			size = v(sx, THICK, sz),
			pitch = pitch,
			color = color,
			sectionIndex = section,
		})
	end

	local function addCheckpoint(order: number, z: number, top: number, section: number)
		table.insert(checkpoints, {
			id = "cp.rubber.001." .. pad(order, 2),
			stageId = STAGE_ID,
			order = order,
			placement = { pos = v(0, top + 4, z), yaw = 0 },
			size = v(24, 8, 12),
			sectionIndex = section,
		})
	end

	-- Entrance plaza + checkpoint 1
	local z = ENTRANCE_Z
	local top = 0
	addPlatform("floor", 0, top, z - PLAZA_LEN / 2, 34, PLAZA_LEN, "trim", 0)
	addCheckpoint(1, z - PLAZA_LEN / 2, top, 0)
	z -= PLAZA_LEN

	for si, spec in SECTIONS do
		local secStart = z
		local secEnd = z - SECTION_LEN
		local cpId = "cp.rubber.001." .. pad(si, 2) -- checkpoint at the plaza before this section

		-- Catch floor for multi-lane sections: 7 below the lanes, extends back under the ramp so it
		-- meets the previous plaza with a single 2-stud step (readable return path).
		if #spec.lanes > 1 then
			local catchTop = top - 7
			local back = RAMP_LEN
			addPlatform("floor", 0, catchTop, (secStart + back + secEnd) / 2, 56, SECTION_LEN + back, "accent", si)
		end

		-- Lanes (split around jump gaps)
		local gapList: { number } = spec.gaps or {}
		for li, lane in spec.lanes do
			local routeId = string.format("route.rubber.001.s%d.%s", si, lane.name)
			table.insert(routes, { id = routeId, stageId = STAGE_ID, sectionIndex = si, lane = lane.name, optional = false })
			local cuts = { 0 }
			for _, g in gapList do
				table.insert(cuts, g)
			end
			table.insert(cuts, SECTION_LEN)
			for ci = 1, #cuts - 1 do
				local a = cuts[ci] + (if ci > 1 then GAP / 2 else 0)
				local b = cuts[ci + 1] - (if ci < #cuts - 1 then GAP / 2 else 0)
				addPlatform("floor", lane.x, top, secStart - (a + b) / 2, lane.width, b - a, "lane:" .. li, si)
			end

			-- Balloons evenly spaced, nudged off any gap so they never float over a hole.
			local spacing = SECTION_LEN / (lane.count + 1)
			for bi = 1, lane.count do
				local along = spacing * bi
				for _, g in gapList do
					if math.abs(along - g) < GAP then
						along = g + (if along < g then -GAP else GAP)
					end
				end
				local x = lane.x
				if lane.name == "single" then
					x = if bi % 2 == 0 then 5 else -5
				end
				slot += 1
				local id = string.format("balloon.rubber.001.%s", pad(slot, 3))
				table.insert(required, id)
				table.insert(balloons, {
					id = id,
					stageId = STAGE_ID,
					routeId = routeId,
					sectionIndex = si,
					required = true,
					pos = v(x, top + BALLOON_LIFT, secStart - along),
					hitRadius = HIT_RADIUS,
					material = MATERIAL,
					theme = THEME,
					colorStep = Palette.stepFor(slot, 100, 0),
					tierKey = spec.tier,
					respawnSeconds = RESPAWN,
				})
			end
		end

		-- Bridges between adjacent lanes (walkable connections; jumping is optional)
		local bridgeList: { number } = spec.bridges or {}
		for _, at in bridgeList do
			for li = 1, #spec.lanes - 1 do
				local l1, l2 = spec.lanes[li], spec.lanes[li + 1]
				local x1 = l1.x + l1.width / 2
				local x2 = l2.x - l2.width / 2
				addPlatform("bridge", (x1 + x2) / 2, top, secStart - at, (x2 - x1) + 2, 6, "trim", si)
			end
		end

		-- Hazards (geometry + typed definition; A runs the behaviour)
		local hazardCounts: { [string]: number } = {}
		local hazardList: { { kind: string, lane: string, at: number } } = spec.hazards or {}
		for _, h in hazardList do
			local laneX = 0
			for _, lane in spec.lanes do
				if lane.name == h.lane then
					laneX = lane.x
				end
			end
			hazardCounts[h.kind] = (hazardCounts[h.kind] or 0) + 1
			local hid = string.format("hazard.rubber.001.s%d.%s.%d", si, h.kind, hazardCounts[h.kind])
			local hz = secStart - h.at
			if h.kind == "sweeper" then
				table.insert(hazards, {
					id = hid,
					stageId = STAGE_ID,
					behaviorKey = "sweeper",
					placement = { pos = v(laneX, top + 2, hz), yaw = 0 },
					-- arm length 18 => sweeps radius 9, exactly the centre lane; side lanes stay safe
					shape = { kind = "box", size = v(18, 1.5, 1.5) },
					params = { armLength = 18, rpm = 9, height = 2, knockback = 30 },
					checkpointId = cpId,
				})
			elseif h.kind == "tack_mat" then
				table.insert(hazards, {
					id = hid,
					stageId = STAGE_ID,
					behaviorKey = "tack_mat",
					placement = { pos = v(laneX, top + 0.25, hz), yaw = 0 },
					shape = { kind = "box", size = v(LANE_W, 0.5, 4) },
					params = { damageHearts = 1, invulnSeconds = 1.5 },
					checkpointId = cpId,
				})
			elseif h.kind == "puff_vent" then
				table.insert(hazards, {
					id = hid,
					stageId = STAGE_ID,
					behaviorKey = "puff_vent",
					placement = { pos = v(laneX, top + 0.2, hz), yaw = 0 },
					shape = { kind = "cylinder", size = v(6, 0.4, 6) },
					params = { period = 4, telegraph = 1, active = 1.2, push = 40, phase = (hazardCounts[h.kind] - 1) * 1.3 },
					checkpointId = cpId,
				})
			end
		end

		-- Optional bonus ledges (2 per section), clearly separate from required lanes.
		local outer = 0
		for _, lane in spec.lanes do
			outer = math.max(outer, math.abs(lane.x) + lane.width / 2)
		end
		for side = -1, 1, 2 do
			bonus += 1
			local lx = side * (outer + 4 + 3)
			local lz = secStart - (if side < 0 then 32 else 64)
			addPlatform("ledge", lx, top + 4, lz, 6, 6, "accent", si)
			local routeId = string.format("route.rubber.001.s%d.bonus", si)
			if side < 0 then
				table.insert(routes, { id = routeId, stageId = STAGE_ID, sectionIndex = si, lane = "bonus", optional = true })
			end
			table.insert(balloons, {
				id = string.format("balloon.rubber.001.bonus.%s", pad(bonus, 2)),
				stageId = STAGE_ID,
				routeId = routeId,
				sectionIndex = si,
				required = false,
				pos = v(lx, top + 4 + BALLOON_LIFT, lz),
				hitRadius = HIT_RADIUS,
				material = MATERIAL,
				theme = THEME,
				colorStep = Palette.stepFor(bonus, 10, 500),
				tierKey = "rubber.bonus",
				respawnSeconds = RESPAWN + 1,
			})
		end

		z = secEnd
		-- Plaza after the section (checkpoint si+1) and ramp up to the next section
		addPlatform("floor", 0, top, z - PLAZA_LEN / 2, 50, PLAZA_LEN, "trim", si)
		addCheckpoint(si + 1, z - PLAZA_LEN / 2, top, si)
		z -= PLAZA_LEN
		if si < #SECTIONS then
			local pitch = math.deg(math.atan(RISE / RAMP_LEN))
			local slopeLen = math.sqrt(RAMP_LEN * RAMP_LEN + RISE * RISE)
			addPlatform("ramp", 0, top + RISE / 2, z - RAMP_LEN / 2, 30, slopeLen, "floor", si, pitch)
			z -= RAMP_LEN
			top += RISE
		end
	end

	-- King Puffer arena (round drum) beyond the final plaza (checkpoint 6 = boss gate)
	local arenaRadius = 42
	-- The round drum floor itself is built by StageBuilder from boss.arenaCenter/arenaRadius.
	local arenaCenter = v(0, top, z - arenaRadius)
	local bossCp = "cp.rubber.001." .. pad(#SECTIONS + 1, 2)

	local minZ = arenaCenter.z - arenaRadius - 10
	return {
		id = STAGE_ID,
		theme = THEME,
		material = MATERIAL,
		displayKey = "stage.rubber.001",
		nextStageId = nil, -- Wood is design-only; this is the last available stage until it is built
		bounds = { min = v(-60, -20, minZ), max = v(60, top + 60, ENTRANCE_Z + 4) },
		start = { pos = v(0, 3, ENTRANCE_Z - 6), yaw = 0 },
		replayStart = { pos = v(0, 3, ENTRANCE_Z - 6), yaw = 0 },
		routes = routes,
		checkpoints = checkpoints,
		balloons = balloons,
		hazards = hazards,
		boss = {
			id = "boss.king_puffer",
			stageId = STAGE_ID,
			behaviorKey = "king_puffer",
			anchor = { pos = v(0, top + 16, arenaCenter.z - 10), yaw = 0 },
			arenaCenter = arenaCenter,
			arenaRadius = arenaRadius,
			-- Suggested defaults only; A owns real timings/damage and may clamp them.
			params = { windup = 1.2, ringSpeed = 18, ringMaxRadius = 38, ringHeight = 3, knotPhase = 6, bodyRadius = 11 },
			checkpointId = bossCp,
			weakPointOffset = v(0, -11, 4),
		},
		platforms = platforms,
		requiredSlotIds = required,
		allowedShortcuts = {},
	}
end

local cached: StageLayout? = nil

return {
	ID = STAGE_ID,
	SECTION_COUNT = #SECTIONS,
	get = function(): StageLayout
		if not cached then
			cached = build()
		end
		return cached :: StageLayout
	end,
}
