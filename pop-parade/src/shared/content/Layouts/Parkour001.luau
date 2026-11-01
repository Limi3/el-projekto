--!strict
-- Parkour course 001: "Ribbon Run". Short, checkpointed, west of the hub.
-- Pure data. Course heads west (-X) from the hub's parkour gate.
--
-- Main path budget (normalised challenge kit, see spec 4): every main-path jump is a 3-stud gap
-- with at most a 3-stud rise, comfortably inside base movement (no extra jump needed).
-- Optional shortcut "Kite Line" uses 7-8 stud gaps and NEEDS the normalised extra jump that every
-- Parkour participant receives, so it never depends on purchases or owned wings.
-- Balloons sit beside the path; none of them is ever a supporting platform.

local Palette = require(script.Parent.Parent.Palette)
local Types = require(script.Parent.Parent.ContentTypes)

type Vec3 = Types.Vec3

local COURSE_ID = "parkour.001"
local THICK = 2
local Z0 = 60 -- course centre line, aligned with the hub parkour gate

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function build(): Types.ParkourLayout
	local platforms: { Types.PlatformLayout } = {}
	local checkpoints: { Types.CheckpointLayout } = {}
	local side: { Types.BalloonLayout } = {}
	local n = 0

	-- x/z are centres; top is the walking surface; sx along X (course direction), sz across.
	local function pad(kind: any, x: number, top: number, z: number, sx: number, sz: number, color: string)
		n += 1
		table.insert(platforms, {
			id = string.format("%s.plat.%02d", COURSE_ID, n),
			kind = kind,
			placement = { pos = v(x, top - THICK / 2, z + Z0), yaw = 0 },
			size = v(sx, THICK, sz),
			color = color,
		})
	end

	local function cp(order: number, x: number, top: number)
		table.insert(checkpoints, {
			id = string.format("cp.parkour.001.%02d", order),
			stageId = COURSE_ID,
			order = order,
			placement = { pos = v(x, top + 4, Z0), yaw = 90 },
			size = v(10, 8, 10),
			sectionIndex = order,
		})
	end

	local function balloon(i: number, x: number, y: number, z: number)
		table.insert(side, {
			id = string.format("balloon.parkour.001.side.%02d", i),
			stageId = COURSE_ID,
			routeId = "route.parkour.001.side",
			sectionIndex = 0,
			required = false,
			pos = v(x, y, z + Z0),
			hitRadius = 2.4,
			material = "rubber",
			theme = "rubber",
			colorStep = Palette.stepFor(i, 8, 300),
			tierKey = "parkour.side",
			respawnSeconds = 4,
		})
	end

	-- 1. Start platform (CP1) – gentle introduction
	pad("floor", -115, 0, 0, 14, 14, "trim")
	cp(1, -115, 0)
	-- stepping stones, 3-stud gaps, flat
	pad("step", -128, 0, 0, 6, 6, "lane:1")
	pad("step", -137, 0, 0, 6, 6, "lane:2")
	pad("step", -146, 0, 0, 6, 6, "lane:3")
	-- 2. CP2
	pad("floor", -158, 0, 0, 12, 12, "trim")
	cp(2, -158, 0)
	balloon(1, -158, 4.5, 8)
	-- rising steps: +2.5 each, 3-stud gaps
	pad("step", -170, 2.5, 0, 6, 6, "lane:1")
	pad("step", -179, 5, 0, 6, 6, "lane:2")
	pad("step", -188, 7.5, 0, 6, 6, "lane:3")
	-- 3. CP3
	pad("floor", -200, 7.5, 0, 12, 12, "trim")
	cp(3, -200, 7.5)
	-- ribbon beam, 3 wide, balloons beside it (not on it)
	pad("bridge", -219, 7.5, 0, 24, 3, "accent")
	balloon(2, -213, 11, 5)
	balloon(3, -221, 11, -5)
	balloon(4, -229, 11, 5)
	-- fork platform
	pad("floor", -236, 7.5, 0, 4, 20, "trim")
	-- main route (z = +6): 3-stud gaps
	pad("step", -243.5, 7.5, 6, 5, 5, "lane:1")
	pad("step", -251.5, 7.5, 6, 5, 5, "lane:2")
	pad("step", -259.5, 7.5, 6, 5, 5, "lane:3")
	pad("step", -267.5, 7.5, 6, 5, 5, "lane:4")
	-- optional shortcut "Kite Line" (z = -6): 7-8 stud gaps, needs the normalised extra jump
	pad("ledge", -247.5, 7.5, -6, 5, 5, "accent")
	pad("ledge", -259.5, 7.5, -6, 5, 5, "accent")
	balloon(5, -253.5, 12, -10)
	-- 4. CP4 (wide so both routes land on it)
	pad("floor", -276, 7.5, 0, 12, 20, "trim")
	cp(4, -276, 7.5)
	-- final climb: +3 rise, 3-stud gaps
	pad("step", -288, 10.5, 0, 6, 6, "lane:1")
	pad("step", -297, 13.5, 0, 6, 6, "lane:2")
	pad("step", -306, 16.5, 0, 6, 6, "lane:3")
	balloon(6, -297, 18, 6)
	-- finish platform + end marker
	pad("floor", -318, 16.5, 0, 12, 12, "trim")
	balloon(7, -318, 21, 7)
	balloon(8, -318, 21, -7)

	return {
		id = COURSE_ID,
		displayKey = "parkour.001",
		start = { pos = v(-115, 3, Z0), yaw = 90 },
		finish = { pos = v(-320, 16.5, Z0), yaw = 90 },
		bounds = { min = v(-332, -25, Z0 - 16), max = v(-100, 45, Z0 + 16) },
		checkpoints = checkpoints,
		platforms = platforms,
		shortcut = {
			id = "shortcut.parkour.001.kite_line",
			fromCheckpoint = "cp.parkour.001.03",
			toCheckpoint = "cp.parkour.001.04",
			note = "From the fork after the ribbon beam, two ledges on the north side with 7-8 stud gaps; requires the normalised extra jump. Skips four 3-stud stones.",
		},
		jumpExpectations = {
			maxGap = 3,
			maxRise = 3,
			needsExtraJump = false,
			note = "Main path never needs the extra jump; only the optional Kite Line shortcut does.",
		},
		sideBalloons = side,
	}
end

local cached: Types.ParkourLayout? = nil

return {
	ID = COURSE_ID,
	get = function(): Types.ParkourLayout
		if not cached then
			cached = build()
		end
		return cached :: Types.ParkourLayout
	end,
}
