--!strict
-- Structural checks for layout data before anything is built. Pure (no Roblox APIs).
--
-- What it proves:   unique IDs, exact 100 required slots, ordered checkpoints, valid links,
--                   finite transforms, every required balloon hovers over solid floor within reach,
--                   and a conservative jump graph reaches every required balloon and the boss arena
--                   from the stage start using ONLY the free base movement kit.
-- What it cannot:   real physics, camera, collisions with decor or "is this fun". Studio playtests
--                   are still required (see docs/b/TEST_RESULTS.md).

local LayoutValidator = {}

-- Base movement budget (WalkSpeed 16, default JumpHeight 7.2). Deliberately conservative.
LayoutValidator.BASE_MAX_GAP = 4
LayoutValidator.BASE_MAX_RISE = 4
-- Parkour challenge kit: everyone gets one extra jump.
LayoutValidator.EXTRA_JUMP_MAX_GAP = 9
LayoutValidator.EXTRA_JUMP_MAX_RISE = 8
LayoutValidator.MAX_REACH = 6.5 -- needle reach is ~6 studs; balloon centre above floor must be within this
LayoutValidator.REQUIRED_SLOTS = 100

type Vec3 = { x: number, y: number, z: number }
type Plat = { id: string, kind: string, placement: { pos: Vec3, yaw: number }, size: Vec3, pitch: number? }

-- A walkable surface reduced to an axis-aligned footprint with a (possibly sloped) top.
type Surface = {
	id: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	topAt: (x: number, z: number) -> number,
}

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function finiteVec(v: any): boolean
	return type(v) == "table" and finite(v.x) and finite(v.y) and finite(v.z)
end

function LayoutValidator.surfaceOf(p: Plat): Surface
	local pos, size = p.placement.pos, p.size
	local yaw = p.placement.yaw or 0
	local sx, sz = size.x, size.z
	if math.abs(yaw % 180 - 90) < 1 then
		sx, sz = sz, sx
	end
	local pitch = p.pitch or 0
	if pitch ~= 0 then
		-- ramp along -Z: footprint shrinks by cos(pitch); top rises toward -Z
		local r = math.rad(pitch)
		local footZ = sz * math.cos(r)
		local rise = sz * math.sin(r)
		local topMid = pos.y + (size.y / 2) * math.cos(r)
		local minZ, maxZ = pos.z - footZ / 2, pos.z + footZ / 2
		return {
			id = p.id,
			minX = pos.x - sx / 2,
			maxX = pos.x + sx / 2,
			minZ = minZ,
			maxZ = maxZ,
			topAt = function(_x: number, z: number): number
				local t = (math.clamp(z, minZ, maxZ) - pos.z) / footZ -- -0.5 at north end
				return topMid - t * rise
			end,
		}
	end
	local top = pos.y + size.y / 2
	return {
		id = p.id,
		minX = pos.x - sx / 2,
		maxX = pos.x + sx / 2,
		minZ = pos.z - sz / 2,
		maxZ = pos.z + sz / 2,
		topAt = function(_x: number, _z: number): number
			return top
		end,
	}
end

function LayoutValidator.diskSurface(id: string, center: Vec3, radius: number): Surface
	-- Treated as its inscribed square for conservative adjacency.
	local h = radius * 0.7071
	return {
		id = id,
		minX = center.x - h,
		maxX = center.x + h,
		minZ = center.z - radius, -- touches the approach plaza along its axis
		maxZ = center.z + radius,
		topAt = function(_x: number, _z: number): number
			return center.y
		end,
	}
end

local function containsXZ(s: Surface, x: number, z: number, margin: number): boolean
	return x >= s.minX - margin and x <= s.maxX + margin and z >= s.minZ - margin and z <= s.maxZ + margin
end

-- Can a player standing anywhere on `a` reach `b` with the given budget?
local function canReach(a: Surface, b: Surface, maxGap: number, maxRise: number): boolean
	local dx = math.max(0, b.minX - a.maxX, a.minX - b.maxX)
	local dz = math.max(0, b.minZ - a.maxZ, a.minZ - b.maxZ)
	local gap = math.sqrt(dx * dx + dz * dz)
	if gap > maxGap then
		return false
	end
	-- closest points between the footprints
	local ax = math.clamp((b.minX + b.maxX) / 2, a.minX, a.maxX)
	local az = math.clamp((b.minZ + b.maxZ) / 2, a.minZ, a.maxZ)
	local bx = math.clamp(ax, b.minX, b.maxX)
	local bz = math.clamp(az, b.minZ, b.maxZ)
	local rise = b.topAt(bx, bz) - a.topAt(ax, az)
	return rise <= maxRise
end

function LayoutValidator.reachable(surfaces: { Surface }, startIndex: number, maxGap: number, maxRise: number): { [string]: boolean }
	local seen: { [string]: boolean } = {}
	local queue = { startIndex }
	seen[surfaces[startIndex].id] = true
	local head = 1
	while head <= #queue do
		local a = surfaces[queue[head]]
		head += 1
		for j, b in surfaces do
			if not seen[b.id] and canReach(a, b, maxGap, maxRise) then
				seen[b.id] = true
				table.insert(queue, j)
			end
		end
	end
	return seen
end

local function supportFor(surfaces: { Surface }, pos: Vec3): Surface?
	local best: Surface? = nil
	local bestTop = -math.huge
	for _, s in surfaces do
		if containsXZ(s, pos.x, pos.z, 0.5) then
			local top = s.topAt(pos.x, pos.z)
			if top <= pos.y and top > bestTop then
				best = s
				bestTop = top
			end
		end
	end
	return best
end

export type Report = { ok: boolean, errors: { string }, warnings: { string }, stats: { [string]: number } }

local function newReport(): Report
	return { ok = true, errors = {}, warnings = {}, stats = {} }
end

local function fail(r: Report, msg: string)
	r.ok = false
	table.insert(r.errors, msg)
end

function LayoutValidator.validateStage(stage: any, knownStageIds: { [string]: boolean }?): Report
	local r = newReport()
	local ids: { [string]: boolean } = {}
	local function claim(id: any, what: string)
		if type(id) ~= "string" or id == "" then
			fail(r, what .. " has no id")
			return
		end
		if id ~= string.lower(id) then
			fail(r, what .. " id must be lowercase: " .. id)
		end
		if ids[id] then
			fail(r, "duplicate id " .. id)
		end
		ids[id] = true
	end
	claim(stage.id, "stage")

	-- routes
	local routes: { [string]: any } = {}
	for _, route in stage.routes do
		claim(route.id, "route")
		routes[route.id] = route
	end

	-- checkpoints: ordered 1..n, contiguous
	local cps: { [string]: any } = {}
	local orders = {}
	for _, cp in stage.checkpoints do
		claim(cp.id, "checkpoint")
		cps[cp.id] = cp
		table.insert(orders, cp.order)
		if not finiteVec(cp.placement.pos) then
			fail(r, "checkpoint transform not finite: " .. cp.id)
		end
	end
	table.sort(orders)
	for i, o in orders do
		if o ~= i then
			fail(r, "checkpoint order must be 1..n without gaps (found " .. tostring(o) .. " at position " .. i .. ")")
			break
		end
	end
	if #orders == 0 then
		fail(r, "stage has no checkpoints")
	end

	-- platforms -> surfaces
	local surfaces: { Surface } = {}
	for _, p in stage.platforms do
		claim(p.id, "platform")
		if not finiteVec(p.placement.pos) or not finiteVec(p.size) then
			fail(r, "platform transform not finite: " .. p.id)
		else
			table.insert(surfaces, LayoutValidator.surfaceOf(p))
		end
	end
	local boss = stage.boss
	if boss == nil then
		fail(r, "stage has no boss")
	else
		claim(boss.id, "boss")
		if not cps[boss.checkpointId] then
			fail(r, "boss checkpoint missing: " .. tostring(boss.checkpointId))
		end
		if not finiteVec(boss.anchor.pos) or not finiteVec(boss.arenaCenter) then
			fail(r, "boss transform not finite")
		end
		table.insert(surfaces, LayoutValidator.diskSurface(boss.id .. ".arena", boss.arenaCenter, boss.arenaRadius))
	end

	for _, h in stage.hazards do
		claim(h.id, "hazard")
		if not cps[h.checkpointId] then
			fail(r, "hazard " .. h.id .. " links missing checkpoint " .. tostring(h.checkpointId))
		end
		for k, val in h.params do
			if not finite(val) then
				fail(r, "hazard " .. h.id .. " param " .. k .. " not finite")
			end
		end
	end

	if stage.nextStageId ~= nil and knownStageIds and not knownStageIds[stage.nextStageId] then
		fail(r, "nextStageId " .. stage.nextStageId .. " is not an enabled stage")
	end

	-- start surface
	local startIndex: number? = nil
	for i, s in surfaces do
		if containsXZ(s, stage.start.pos.x, stage.start.pos.z, 0) and s.topAt(stage.start.pos.x, stage.start.pos.z) <= stage.start.pos.y then
			startIndex = i
			break
		end
	end
	if not startIndex then
		fail(r, "stage start is not above any platform")
		return r
	end
	local reach = LayoutValidator.reachable(surfaces, startIndex :: number, LayoutValidator.BASE_MAX_GAP, LayoutValidator.BASE_MAX_RISE)

	-- balloons
	local requiredCount, optionalCount = 0, 0
	local requiredSet: { [string]: boolean } = {}
	for _, b in stage.balloons do
		claim(b.id, "balloon")
		if not finiteVec(b.pos) or not finite(b.hitRadius) then
			fail(r, "balloon transform not finite: " .. b.id)
			continue
		end
		local route = routes[b.routeId]
		if not route then
			fail(r, "balloon " .. b.id .. " has unknown route " .. tostring(b.routeId))
		elseif b.required and route.optional then
			fail(r, "required balloon " .. b.id .. " sits on optional route " .. b.routeId)
		end
		if b.respawnSeconds < 3 or b.respawnSeconds > 6 then
			table.insert(r.warnings, "balloon " .. b.id .. " respawn " .. b.respawnSeconds .. "s outside 3-6s")
		end
		if b.colorStep < 0 or b.colorStep >= 1000 or b.colorStep % 1 ~= 0 then
			fail(r, "balloon " .. b.id .. " colorStep out of range")
		end
		local support = supportFor(surfaces, b.pos)
		if not support then
			fail(r, "balloon " .. b.id .. " floats over no floor")
		else
			local lift = b.pos.y - support.topAt(b.pos.x, b.pos.z)
			if lift > LayoutValidator.MAX_REACH then
				fail(r, string.format("balloon %s is %.1f studs above its floor (reach %.1f)", b.id, lift, LayoutValidator.MAX_REACH))
			end
			if b.required and not reach[support.id] then
				fail(r, "required balloon " .. b.id .. " is unreachable with base movement")
			end
		end
		if b.required then
			requiredCount += 1
			requiredSet[b.id] = true
		else
			optionalCount += 1
		end
	end
	if requiredCount ~= LayoutValidator.REQUIRED_SLOTS then
		fail(r, string.format("stage must have exactly %d required slots, has %d", LayoutValidator.REQUIRED_SLOTS, requiredCount))
	end
	if #stage.requiredSlotIds ~= requiredCount then
		fail(r, "requiredSlotIds count does not match required balloons")
	end
	for _, id in stage.requiredSlotIds do
		if not requiredSet[id] then
			fail(r, "requiredSlotIds lists unknown/non-required balloon " .. id)
		end
	end
	if boss and not reach[boss.id .. ".arena"] then
		fail(r, "boss arena unreachable with base movement")
	end

	r.stats.required = requiredCount
	r.stats.optional = optionalCount
	r.stats.platforms = #stage.platforms
	r.stats.checkpoints = #stage.checkpoints
	r.stats.hazards = #stage.hazards
	local reached = 0
	for _ in reach do
		reached += 1
	end
	r.stats.reachableSurfaces = reached
	r.stats.surfaces = #surfaces
	return r
end

function LayoutValidator.validateParkour(course: any): Report
	local r = newReport()
	local surfaces: { Surface } = {}
	local ids: { [string]: boolean } = {}
	for _, p in course.platforms do
		if ids[p.id] then
			fail(r, "duplicate id " .. p.id)
		end
		ids[p.id] = true
		table.insert(surfaces, LayoutValidator.surfaceOf(p))
	end
	local function surfaceUnder(pos: Vec3): number?
		for i, s in surfaces do
			if containsXZ(s, pos.x, pos.z, 0) and s.topAt(pos.x, pos.z) <= pos.y + 0.01 then
				return i
			end
		end
		return nil
	end
	local startI = surfaceUnder(course.start.pos)
	local finishI = surfaceUnder(course.finish.pos)
	if not startI then
		fail(r, "parkour start not above a platform")
		return r
	end
	if not finishI then
		fail(r, "parkour finish marker not on a platform")
		return r
	end
	local base = LayoutValidator.reachable(surfaces, startI :: number, LayoutValidator.BASE_MAX_GAP, LayoutValidator.BASE_MAX_RISE)
	if not base[surfaces[finishI :: number].id] then
		fail(r, "parkour main path cannot reach the finish with base movement")
	end
	for _, cp in course.checkpoints do
		local i = surfaceUnder({ x = cp.placement.pos.x, y = cp.placement.pos.y, z = cp.placement.pos.z })
		if not i then
			fail(r, "checkpoint " .. cp.id .. " not over a platform")
		elseif not base[surfaces[i].id] then
			fail(r, "checkpoint " .. cp.id .. " unreachable with base movement")
		end
	end
	-- Shortcut ledges must need the extra jump (otherwise it's not really a shortcut decision)
	local extra = LayoutValidator.reachable(surfaces, startI :: number, LayoutValidator.EXTRA_JUMP_MAX_GAP, LayoutValidator.EXTRA_JUMP_MAX_RISE)
	local ledges, ledgesBase, ledgesExtra = 0, 0, 0
	for _, p in course.platforms do
		if p.kind == "ledge" then
			ledges += 1
			if base[p.id] then
				ledgesBase += 1
			end
			if extra[p.id] then
				ledgesExtra += 1
			end
		end
	end
	if ledges > 0 and ledgesExtra ~= ledges then
		fail(r, "shortcut ledges unreachable even with the normalised extra jump")
	end
	for _, b in course.sideBalloons do
		local i = surfaceUnder(b.pos)
		if i then
			local top = surfaces[i].topAt(b.pos.x, b.pos.z)
			if b.pos.y - top < 2 then
				fail(r, "side balloon " .. b.id .. " sits on/inside a platform")
			end
		end
	end
	r.stats.platforms = #course.platforms
	r.stats.checkpoints = #course.checkpoints
	r.stats.shortcutLedges = ledges
	r.stats.shortcutLedgesReachableWithoutExtraJump = ledgesBase
	return r
end

-- Secrets: free basic movement only. `surfaces` come from the built geometry descriptions.
function LayoutValidator.validateSecretAccess(secretPos: Vec3, surfaces: { Surface }, startIndex: number): boolean
	local reach = LayoutValidator.reachable(surfaces, startIndex, LayoutValidator.BASE_MAX_GAP, LayoutValidator.BASE_MAX_RISE)
	local s = supportFor(surfaces, secretPos)
	return s ~= nil and reach[s.id] == true and (secretPos.y - s.topAt(secretPos.x, secretPos.z)) <= LayoutValidator.MAX_REACH
end

return LayoutValidator
