--!strict
-- SERVER-ONLY. Golden secret placements and the geometry that hides them.
-- Never move this into ReplicatedStorage and never send these positions to clients: the client
-- journal only receives discovered IDs/names from A's state. (Map geometry itself can always be
-- inspected by determined players; this only avoids handing out a coordinate list.)
-- Full spoiler notes: docs/b/SECRETS.md
--
-- Pure data (no Roblox APIs) so access can be checked by the unit tests.

local SecretsLayout = {}

type Vec3 = { x: number, y: number, z: number }

export type SecretPlacement = {
	id: string,
	nameKey: string,
	theme: string,
	buffKey: string, -- A validates against its server registry
	pos: Vec3,
	triggerRadius: number,
	clue: string, -- designer note (also in SECRETS.md)
}

export type Box = { name: string, center: Vec3, size: Vec3, walkable: boolean }

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- Fizzy Falls rock wall with a hidden alcove (hub, north-east)
SecretsLayout.FALLS = {
	wallZ = -43, -- wall centre z (thickness 6 -> z -40..-46)
	wallMinX = 62,
	wallMaxX = 88,
	openMinX = 72,
	openMaxX = 78,
	height = 18,
	openHeight = 8,
	caveBackZ = -58,
}

-- Big Top tent (hub, south-west of spawn)
SecretsLayout.TENT = {
	center = v(-30, 0, 82),
	wallRadius = 10,
	wallHeight = 10,
	layers = 7,
	layerRise = 1.2,
	firstRadius = 11,
	inset = 1.3,
	crates = { v(-10, 0, 82), v(-13, 0, 82), v(-16, 0, 82) }, -- column bases, heights 1/2/3 crates
	crateSize = 3,
}

function SecretsLayout.tentLayers(): { { top: number, radius: number } }
	local t = SecretsLayout.TENT
	local out = {}
	for k = 0, t.layers - 1 do
		table.insert(out, { top = t.wallHeight + 1 + k * t.layerRise, radius = t.firstRadius - k * t.inset })
	end
	return out
end

-- Rubber stage section 2: first bridge between the two lanes. Computed from the stage layout so the
-- secret moves with the bridge if the layout changes.
function SecretsLayout.underBridgeAnchor(rubberLayout: any): (Vec3, number)
	for _, p in rubberLayout.platforms do
		if p.kind == "bridge" and p.sectionIndex == 2 then
			local laneTop = p.placement.pos.y + p.size.y / 2
			local catchTop = laneTop - 7
			return v(p.placement.pos.x, catchTop + 2.5, p.placement.pos.z), catchTop
		end
	end
	error("SecretsLayout: section 2 bridge not found in Rubber layout")
end

function SecretsLayout.placements(rubberLayout: any): { SecretPlacement }
	local f = SecretsLayout.FALLS
	local tentTop = SecretsLayout.tentLayers()
	local cap = tentTop[#tentTop]
	local bridgePos = SecretsLayout.underBridgeAnchor(rubberLayout)
	return {
		{
			id = "secret.rubber.waterfall",
			nameKey = "secret.rubber.waterfall",
			theme = "hub",
			buffKey = "buff.secret.speed_1pct",
			pos = v((f.openMinX + f.openMaxX) / 2, 4.5, -52),
			triggerRadius = 5,
			clue = "A trail of fizzy bubbles on the ground runs toward the falls and disappears into the water.",
		},
		{
			id = "secret.hub.big_top",
			nameKey = "secret.hub.big_top",
			theme = "hub",
			buffKey = "buff.secret.attack_1pct",
			pos = v(SecretsLayout.TENT.center.x, cap.top + 4, SecretsLayout.TENT.center.z),
			triggerRadius = 5,
			clue = "A stack of crates beside the tent; the lowest crate has a small gold star sticker.",
		},
		{
			id = "secret.rubber.underbridge",
			nameKey = "secret.rubber.underbridge",
			theme = "rubber",
			buffKey = "buff.secret.needle_1pct",
			pos = bridgePos,
			triggerRadius = 6,
			clue = "Arrow-shaped tiles on the safety floor below section 2 point at the first bridge.",
		},
	}
end

-- Walkable boxes for access checks (hub floor + crates + tent roof layers as inscribed squares).
function SecretsLayout.hubSurfaces(): { any }
	local out = {}
	local function box(id: string, cx: number, top: number, cz: number, sx: number, sz: number)
		table.insert(out, {
			id = id,
			kind = "floor",
			placement = { pos = v(cx, top - 1, cz), yaw = 0 },
			size = v(sx, 2, sz),
		})
	end
	-- r=100 plaza disk as 10-stud slabs that stay inside the circle (first slab = start surface)
	local order = { 0 }
	for k = 1, 10 do
		table.insert(order, -k)
		table.insert(order, k)
	end
	for _, k in order do
		local z0, z1 = k * 10, k * 10 + 10
		local far = math.max(math.abs(z0), math.abs(z1))
		if far < 100 then
			local halfX = math.sqrt(100 * 100 - far * far)
			box("hub.floor." .. k, 0, 0, (z0 + z1) / 2, halfX * 2, 10)
		end
	end
	local t = SecretsLayout.TENT
	for i, base in t.crates do
		box("hub.crate." .. i, base.x, i * t.crateSize, base.z, t.crateSize, t.crateSize)
	end
	-- Each round roof layer as a "plus" of two strips that stay inside the circle
	-- (corner at (0.95r, 0.3r) has length 0.996r).
	for i, layer in SecretsLayout.tentLayers() do
		local r = layer.radius
		box("hub.tent.layer." .. i .. ".x", t.center.x, layer.top, t.center.z, 1.9 * r, 0.6 * r)
		box("hub.tent.layer." .. i .. ".z", t.center.x, layer.top, t.center.z, 0.6 * r, 1.9 * r)
	end
	return out
end

return SecretsLayout
