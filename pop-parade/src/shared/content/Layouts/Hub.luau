--!strict
-- Hub plaza layout data (public). Pure, deterministic.
-- Contains only things every client may know: spawn, practice trail, stations and gates.
-- Secret locations are NOT here (see src/server/world/Secrets.luau, server-only).
--
-- yaw convention: degrees about +Y; yaw 0 faces -Z (north, toward the Rubber stage),
-- yaw -90 faces +X (east), yaw 90 faces -X (west), yaw 180 faces +Z (south).

local Palette = require(script.Parent.Parent.Palette)
local Types = require(script.Parent.Parent.ContentTypes)

type Vec3 = Types.Vec3

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local Hub = {}

Hub.PLAZA_RADIUS = 100
Hub.SPAWN = { pos = v(0, 3, 58), yaw = 0 } :: Types.Placement
Hub.STAGE_GATE_Z = -100 -- arch at the plaza's north edge; Rubber entrance plaza starts at z = -110
Hub.PARKOUR_GATE = { pos = v(-88, 0, 60), yaw = 90 } :: Types.Placement

-- Free practice trail: starts 7 studs in front of spawn so the first pop happens within seconds.
local function practiceBalloons(): { Types.BalloonLayout }
	local out = {}
	for i = 1, 8 do
		local z = 51 - (i - 1) * 5
		local x = if i % 2 == 0 then 3 else -3
		table.insert(out, {
			id = string.format("balloon.hub.practice.%02d", i),
			stageId = "stage.hub",
			routeId = "route.hub.practice",
			sectionIndex = 0,
			required = false,
			pos = v(x, 4.5, z),
			hitRadius = 2.6,
			material = "rubber",
			theme = "hub",
			colorStep = Palette.stepFor(i, 8, 100),
			tierKey = "hub.practice",
			respawnSeconds = 3,
		})
	end
	return out
end

local function markers(): { Types.DecorMarker }
	local out: { Types.DecorMarker } = {}
	-- Five upgrade kiosks on the west arc, facing east toward the centre.
	local upgrades = { "Needle", "Speed", "Attack", "Hits", "Life" }
	for i, upgradeId in upgrades do
		table.insert(out, {
			id = "kiosk.upgrade." .. string.lower(upgradeId),
			kind = "kiosk.upgrades",
			placement = { pos = v(-56, 0, -36 + (i - 1) * 16), yaw = -90 },
			radius = 10,
			data = { upgradeId = upgradeId },
		})
	end
	-- Cosmetics displays on the east arc, facing west.
	local displays = {
		{ id = "display.trail.rainbow", item = "trail.rainbow" },
		{ id = "display.trail.rocket", item = "trail.rocket" },
		{ id = "display.trail.neon", item = "trail.neon" },
		{ id = "display.wings.basic", item = "wings.basic" },
	}
	for i, d in displays do
		table.insert(out, {
			id = d.id,
			kind = "display.cosmetics",
			placement = { pos = v(56, 0, -30 + (i - 1) * 18), yaw = 90 },
			radius = 10,
			data = { itemId = d.item },
		})
	end
	table.insert(out, { id = "wheel.hub", kind = "wheel", placement = { pos = v(-40, 0, -66), yaw = 180 }, radius = 14 })
	table.insert(out, { id = "rewards.hub", kind = "rewards", placement = { pos = v(40, 0, -66), yaw = 180 }, radius = 12 })
	table.insert(out, {
		id = "gate.stage.rubber.001",
		kind = "gate.stage",
		placement = { pos = v(0, 0, Hub.STAGE_GATE_Z), yaw = 0 },
		radius = 14,
		data = { stageId = "stage.rubber.001" },
	})
	table.insert(out, {
		id = "gate.parkour.001",
		kind = "gate.parkour",
		placement = Hub.PARKOUR_GATE,
		radius = 12,
		data = { courseId = "parkour.001" },
	})
	table.insert(out, {
		id = "sign.next_theme.wood",
		kind = "sign",
		placement = { pos = v(30, 0, -92), yaw = 0 },
		radius = 8,
		data = { textKey = "hub.sign.wood_wip" },
	})
	return out
end

local function afkStations(): { Types.AfkStationLayout }
	return {
		{ id = "afk.hub.free.01", tier = "free", placement = { pos = v(42, 0, 62), yaw = 0 }, balloonPos = v(42, 9, 50), radius = 6 },
		{ id = "afk.hub.free.02", tier = "free", placement = { pos = v(58, 0, 62), yaw = 0 }, balloonPos = v(58, 9, 50), radius = 6 },
		{ id = "afk.hub.premium.01", tier = "premium", placement = { pos = v(78, 0, 78), yaw = 0 }, balloonPos = v(78, 12, 62), radius = 7 },
	}
end

local cache: any = nil

function Hub.get(): {
	spawn: Types.Placement,
	practice: { Types.BalloonLayout },
	markers: { Types.DecorMarker },
	afk: { Types.AfkStationLayout },
}
	if not cache then
		cache = { spawn = Hub.SPAWN, practice = practiceBalloons(), markers = markers(), afk = afkStations() }
	end
	return cache
end

return Hub
