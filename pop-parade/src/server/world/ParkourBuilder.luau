--!strict
-- Builds the Ribbon Run parkour course geometry from Content.Layouts.Parkour001.
-- A owns timing, checkpoint validation, normalised stats and rewards; this is geometry + markers.

local Geometry = require(script.Parent.Geometry)

local ParkourBuilder = {}

local WHITE = { r = 1, g = 1, b = 1 }
local LANE_STEPS = { 60, 240, 480, 760 }

function ParkourBuilder.build(Content: any, parent: Instance): { model: Model, checkpointVolumes: { [string]: BasePart }, finish: BasePart }
	local Palette = Content.Palette
	local Strings = Content.Strings
	local course = Content.Layouts.Parkour001.get()
	local theme = Content.Themes.get("rubber")
	local model = Geometry.model(parent, course.id)
	Geometry.tag(model, { PopParadeCourse = course.id })
	local floors = Geometry.folder(model, "Floors")
	local decor = Geometry.folder(model, "Decor")

	local function colorOf(key: string): any
		if key == "trim" then
			return Palette.mix(theme.trim, WHITE, 0.2)
		elseif key == "accent" then
			return Content.Branding.golden
		end
		local n = tonumber(string.match(key, "^lane:(%d+)$") or "") or 1
		return Palette.mix(Palette.color(LANE_STEPS[((n - 1) % #LANE_STEPS) + 1]), WHITE, 0.3)
	end

	for _, p in course.platforms do
		local part = Geometry.part(floors, p.id, Geometry.v3(p.size), Geometry.cf(p.placement.pos, p.placement.yaw), colorOf(p.color))
		Geometry.tag(part, { PopParadeSurface = p.kind })
		if p.kind == "ledge" then
			Geometry.tag(part, { PopParadeShortcut = course.shortcut.id })
		end
	end

	local volumes: { [string]: BasePart } = {}
	for _, cp in course.checkpoints do
		local pos = Geometry.v3(cp.placement.pos)
		local vol = Geometry.part(model, cp.id, Geometry.v3(cp.size), CFrame.new(pos), WHITE, { transparency = 1, canCollide = false, castShadow = false })
		Geometry.tag(vol, { PopParadeCheckpoint = cp.id, Order = cp.order, StageId = course.id })
		volumes[cp.id] = vol
		local floorTop = pos.Y - cp.size.y / 2
		Geometry.column(decor, cp.id .. ".pole", pos.X, floorTop, pos.Z - 5.5, 0.3, 8, WHITE, { canCollide = false })
		Geometry.part(decor, cp.id .. ".flag", Vector3.new(2.6, 1.6, 0.15), CFrame.new(pos.X - 1.3, floorTop + 7.2, pos.Z - 5.5), theme.trim, { canCollide = false })
		Geometry.sign(decor, cp.id .. ".num", CFrame.new(pos.X, floorTop + 4.8, pos.Z - 5.5) * CFrame.Angles(0, math.rad(-90), 0), Vector2.new(1.8, 1.8), tostring(cp.order), WHITE, theme.trim)
	end

	-- Start sign (explains the normalised challenge rules up front)
	local s = course.start.pos
	Geometry.sign(decor, "RulesSign", CFrame.new(s.x + 6, 4, s.z + 6.5) * CFrame.Angles(0, math.rad(-90), 0), Vector2.new(10, 3), Strings.t("parkour.normalized"), WHITE, theme.trim)

	-- Finish arch + end marker volume
	local f = course.finish.pos
	for side = -1, 1, 2 do
		Geometry.column(decor, "FinishPost", f.x, f.y, f.z + side * 5, 0.5, 10, WHITE, { canCollide = false })
	end
	for i = 0, 9 do
		Geometry.part(decor, "FinishBand", Vector3.new(0.4, 1.4, 1), CFrame.new(f.x, f.y + 10, f.z - 4.5 + i), if i % 2 == 0 then WHITE else { r = 0.15, g = 0.15, b = 0.2 }, { canCollide = false })
	end
	local finish = Geometry.part(model, "FinishMarker", Vector3.new(6, 8, 10), CFrame.new(f.x, f.y + 4, f.z), WHITE, { transparency = 1, canCollide = false, castShadow = false })
	Geometry.tag(finish, { PopParadeFinish = course.id })

	return { model = model, checkpointVolumes = volumes, finish = finish }
end

return ParkourBuilder
