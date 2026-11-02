--!strict
-- POP PARADE WorldBuilder (B-owned). Contract interface:
--     WorldBuilder.Build(parent: Instance, options: BuildOptions): WorldManifest
--     WorldBuilder.Destroy(manifest: WorldManifest)
--
-- Build is deterministic: same options -> same geometry and IDs. It creates geometry and typed
-- metadata only. It never starts combat loops, awards Coins, validates purchases, writes saves or
-- calls DataStores. A calls it exactly once in the production bootstrap, validates the manifest and
-- registers entities in its own systems.
--
-- PROVISIONAL FIELD NAMES: the manifest shape below is B's proposal (docs/b/CONTRACT_REQUESTS.md).
-- When A's src/shared/contracts lands, B adapts this file to A's exact types.
--
-- PRIVACY: manifest.secrets contains secret coordinates. Keep the manifest on the server; never
-- replicate it wholesale. Clients get balloon defs/state through A's WorldUpdate messages.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Geometry = require(script.Parent.Geometry)
local LayoutValidator = require(script.Parent.LayoutValidator)
local StageBuilder = require(script.Parent.StageBuilder)
local HubBuilder = require(script.Parent.HubBuilder)
local ParkourBuilder = require(script.Parent.ParkourBuilder)
local SecretsBuilder = require(script.Parent.SecretsBuilder)
local SecretsLayout = require(script.Parent.SecretsLayout)

local function content(): any
	return require(ReplicatedStorage:WaitForChild("PopParade"):WaitForChild("Content") :: ModuleScript) :: any
end

local WorldBuilder = {}
WorldBuilder.SCHEMA_VERSION = 1

export type BuildOptions = {
	seed: number,
	enabledStageIds: { string },
	testMode: boolean,
}

export type BalloonDef = {
	id: string,
	stageId: string,
	routeId: string,
	sectionIndex: number,
	required: boolean,
	position: Vector3, -- authoritative logical centre (no cosmetic bob)
	hitRadius: number,
	material: string,
	theme: string,
	colorStep: number,
	tierKey: string,
	respawnSeconds: number,
}

export type CheckpointDef = { id: string, stageId: string, order: number, cframe: CFrame, size: Vector3, volume: BasePart }

export type HazardDef = {
	id: string,
	stageId: string,
	behaviorKey: string,
	cframe: CFrame,
	shape: { kind: string, size: Vector3 },
	params: { [string]: number },
	checkpointId: string,
	instance: Model,
}

export type BossDef = {
	id: string,
	stageId: string,
	behaviorKey: string,
	anchor: CFrame,
	arenaCenter: Vector3,
	arenaRadius: number,
	params: { [string]: number },
	checkpointId: string,
	weakPointOffset: Vector3,
}

export type StageDef = {
	id: string,
	theme: string,
	material: string,
	nextStageId: string?,
	bounds: { min: Vector3, max: Vector3 },
	start: CFrame,
	replayStart: CFrame,
	routeIds: { string },
	checkpointIds: { string },
	requiredSlotIds: { string },
	bossId: string,
	allowedShortcuts: { string },
}

export type RouteDef = { id: string, stageId: string, sectionIndex: number, lane: string, optional: boolean }

export type SecretDef = {
	id: string,
	cframe: CFrame,
	triggerRadius: number,
	theme: string,
	buffKey: string,
	nameKey: string,
	instance: Model,
}

export type AfkStationDef = { id: string, tier: "free" | "premium", stand: CFrame, balloonPosition: Vector3, radius: number }

export type ParkourDef = {
	id: string,
	start: CFrame,
	finish: CFrame,
	finishVolume: BasePart,
	bounds: { min: Vector3, max: Vector3 },
	checkpoints: { CheckpointDef },
	shortcut: { id: string, fromCheckpoint: string, toCheckpoint: string, note: string },
	jumpExpectations: { maxGap: number, maxRise: number, needsExtraJump: boolean, note: string },
	sideBalloonIds: { string },
}

export type DecorMarkerDef = { id: string, kind: string, cframe: CFrame, radius: number, data: { [string]: any }?, instance: Model? }

export type WorldManifest = {
	schemaVersion: number,
	seed: number,
	testMode: boolean,
	root: Model,
	spawn: CFrame,
	stages: { StageDef },
	routes: { RouteDef },
	checkpoints: { CheckpointDef },
	balloons: { BalloonDef },
	bosses: { BossDef },
	hazards: { HazardDef },
	secrets: { SecretDef }, -- PRIVATE: server only
	afkStations: { AfkStationDef },
	parkourCourses: { ParkourDef },
	decor: { DecorMarkerDef },
	validation: { [string]: any }, -- B's structural report per stage/course (for A's logs)
}

local function v3(p: any): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function cfOf(placement: any): CFrame
	return Geometry.cf(placement.pos, placement.yaw)
end

local function balloonDef(b: any): BalloonDef
	return {
		id = b.id,
		stageId = b.stageId,
		routeId = b.routeId,
		sectionIndex = b.sectionIndex,
		required = b.required,
		position = v3(b.pos),
		hitRadius = b.hitRadius,
		material = b.material,
		theme = b.theme,
		colorStep = b.colorStep,
		tierKey = b.tierKey,
		respawnSeconds = b.respawnSeconds,
	}
end

-- Registry of stage layouts B has actually built. "design" themes are NOT here on purpose.
local function stageLayouts(Content: any): { [string]: any }
	return {
		["stage.rubber.001"] = Content.Layouts.RubberStage001,
	}
end

function WorldBuilder.Build(parent: Instance, options: BuildOptions): WorldManifest
	assert(typeof(parent) == "Instance", "WorldBuilder.Build: parent must be an Instance")
	assert(type(options) == "table", "WorldBuilder.Build: options required")
	assert(type(options.seed) == "number" and options.seed == options.seed, "WorldBuilder.Build: options.seed must be a number")
	assert(type(options.enabledStageIds) == "table", "WorldBuilder.Build: options.enabledStageIds required")
	local Content = content()
	local registry = stageLayouts(Content)

	local enabled: { [string]: boolean } = {}
	for _, id in options.enabledStageIds do
		if not registry[id] then
			error("WorldBuilder.Build: stage '" .. tostring(id) .. "' has no built layout (design-only themes cannot be enabled)")
		end
		enabled[id] = true
	end

	-- Validate every layout BEFORE creating any Instances so failures are clean.
	local validation: { [string]: any } = {}
	for id in enabled do
		local report = LayoutValidator.validateStage(registry[id].get(), enabled)
		validation[id] = report
		if not report.ok then
			error("WorldBuilder.Build: stage " .. id .. " failed validation:\n  " .. table.concat(report.errors, "\n  "))
		end
	end
	local parkourLayout = Content.Layouts.Parkour001.get()
	local parkourReport = LayoutValidator.validateParkour(parkourLayout)
	validation[parkourLayout.id] = parkourReport
	if not parkourReport.ok then
		error("WorldBuilder.Build: parkour failed validation:\n  " .. table.concat(parkourReport.errors, "\n  "))
	end

	local root = Instance.new("Model")
	root.Name = "PopParadeWorld"
	root:SetAttribute("PopParadeSchema", WorldBuilder.SCHEMA_VERSION)
	root:SetAttribute("Seed", options.seed)
	root:SetAttribute("TestMode", options.testMode == true)

	local manifest: WorldManifest = {
		schemaVersion = WorldBuilder.SCHEMA_VERSION,
		seed = options.seed,
		testMode = options.testMode == true,
		root = root,
		spawn = CFrame.new(),
		stages = {},
		routes = {},
		checkpoints = {},
		balloons = {},
		bosses = {},
		hazards = {},
		secrets = {},
		afkStations = {},
		parkourCourses = {},
		decor = {},
		validation = validation,
	}

	-- Hub
	local hubLayout = Content.Layouts.Hub.get()
	local builtHub = HubBuilder.build(Content, root)
	manifest.spawn = cfOf(hubLayout.spawn)
	for _, b in hubLayout.practice do
		table.insert(manifest.balloons, balloonDef(b))
	end
	for _, mk in hubLayout.markers do
		table.insert(manifest.decor, { id = mk.id, kind = mk.kind, cframe = cfOf(mk.placement), radius = mk.radius, data = mk.data, instance = builtHub.markerModels[mk.id] })
	end
	for _, st in hubLayout.afk do
		table.insert(manifest.afkStations, { id = st.id, tier = st.tier, stand = cfOf(st.placement), balloonPosition = v3(st.balloonPos), radius = st.radius })
	end

	-- Stages (sorted for determinism)
	local ids = {}
	for id in enabled do
		table.insert(ids, id)
	end
	table.sort(ids)
	local stagesFolder = Geometry.folder(root, "Stages")
	for _, id in ids do
		local layout = registry[id].get()
		local built = StageBuilder.build(Content, layout, stagesFolder)
		local routeIds, cpIds = {}, {}
		for _, r in layout.routes do
			table.insert(manifest.routes, { id = r.id, stageId = r.stageId, sectionIndex = r.sectionIndex, lane = r.lane, optional = r.optional })
			table.insert(routeIds, r.id)
		end
		for _, cp in layout.checkpoints do
			table.insert(manifest.checkpoints, { id = cp.id, stageId = cp.stageId, order = cp.order, cframe = cfOf(cp.placement), size = v3(cp.size), volume = built.checkpointVolumes[cp.id] })
			table.insert(cpIds, cp.id)
		end
		for _, b in layout.balloons do
			table.insert(manifest.balloons, balloonDef(b))
		end
		for _, h in layout.hazards do
			table.insert(manifest.hazards, {
				id = h.id,
				stageId = h.stageId,
				behaviorKey = h.behaviorKey,
				cframe = cfOf(h.placement),
				shape = { kind = h.shape.kind, size = v3(h.shape.size) },
				params = table.clone(h.params),
				checkpointId = h.checkpointId,
				instance = built.hazardModels[h.id],
			})
		end
		local boss = layout.boss
		table.insert(manifest.bosses, {
			id = boss.id,
			stageId = boss.stageId,
			behaviorKey = boss.behaviorKey,
			anchor = cfOf(boss.anchor),
			arenaCenter = v3(boss.arenaCenter),
			arenaRadius = boss.arenaRadius,
			params = table.clone(boss.params),
			checkpointId = boss.checkpointId,
			weakPointOffset = v3(boss.weakPointOffset),
		})
		table.insert(manifest.stages, {
			id = layout.id,
			theme = layout.theme,
			material = layout.material,
			nextStageId = if layout.nextStageId and enabled[layout.nextStageId] then layout.nextStageId else nil,
			bounds = { min = v3(layout.bounds.min), max = v3(layout.bounds.max) },
			start = cfOf(layout.start),
			replayStart = cfOf(layout.replayStart),
			routeIds = routeIds,
			checkpointIds = cpIds,
			requiredSlotIds = table.clone(layout.requiredSlotIds),
			bossId = boss.id,
			allowedShortcuts = table.clone(layout.allowedShortcuts),
		})
	end

	-- Parkour
	local builtPk = ParkourBuilder.build(Content, root)
	local pkCps: { CheckpointDef } = {}
	for _, cp in parkourLayout.checkpoints do
		local def = { id = cp.id, stageId = parkourLayout.id, order = cp.order, cframe = cfOf(cp.placement), size = v3(cp.size), volume = builtPk.checkpointVolumes[cp.id] }
		table.insert(pkCps, def)
	end
	local sideIds = {}
	for _, b in parkourLayout.sideBalloons do
		table.insert(manifest.balloons, balloonDef(b))
		table.insert(sideIds, b.id)
	end
	table.insert(manifest.parkourCourses, {
		id = parkourLayout.id,
		start = cfOf(parkourLayout.start),
		finish = cfOf(parkourLayout.finish),
		finishVolume = builtPk.finish,
		bounds = { min = v3(parkourLayout.bounds.min), max = v3(parkourLayout.bounds.max) },
		checkpoints = pkCps,
		shortcut = table.clone(parkourLayout.shortcut),
		jumpExpectations = table.clone(parkourLayout.jumpExpectations),
		sideBalloonIds = sideIds,
	})

	-- Secrets (only when the Rubber stage is enabled, since one lives under its bridge)
	if enabled["stage.rubber.001"] then
		local rubber = registry["stage.rubber.001"].get()
		local models = SecretsBuilder.build(Content, rubber, root)
		for _, s in SecretsLayout.placements(rubber) do
			table.insert(manifest.secrets, {
				id = s.id,
				cframe = CFrame.new(v3(s.pos)),
				triggerRadius = s.triggerRadius,
				theme = s.theme,
				buffKey = s.buffKey,
				nameKey = s.nameKey,
				instance = models[s.id],
			})
		end
	end

	if manifest.testMode then
		-- Behind and above spawn (players face north toward the balloons), so it never blocks play.
		local sp = hubLayout.spawn.pos
		Geometry.sign(root, "TestBuildSign", CFrame.new(sp.x, 14, sp.z + 16), Vector2.new(16, 2.4), Content.Strings.t("hud.preview_banner"), { r = 1, g = 0.95, b = 0.6 }, { r = 0.6, g = 0.2, b = 0.1 })
	end

	-- Final ID uniqueness across the whole manifest
	local seen: { [string]: string } = {}
	local function claim(id: string, kind: string)
		if seen[id] then
			error(string.format("WorldBuilder.Build: duplicate id %s (%s and %s)", id, seen[id], kind))
		end
		seen[id] = kind
	end
	for _, x in manifest.stages do claim(x.id, "stage") end
	for _, x in manifest.routes do claim(x.id, "route") end
	for _, x in manifest.checkpoints do claim(x.id, "checkpoint") end
	for _, x in manifest.balloons do claim(x.id, "balloon") end
	for _, x in manifest.bosses do claim(x.id, "boss") end
	for _, x in manifest.hazards do claim(x.id, "hazard") end
	for _, x in manifest.secrets do claim(x.id, "secret") end
	for _, x in manifest.afkStations do claim(x.id, "afk") end
	for _, x in manifest.parkourCourses do
		claim(x.id, "parkour")
		for _, cp in x.checkpoints do claim(cp.id, "checkpoint") end
	end
	for _, x in manifest.decor do claim(x.id, "decor") end

	root.Parent = parent
	return manifest
end

function WorldBuilder.Destroy(manifest: WorldManifest)
	if manifest and manifest.root then
		manifest.root:Destroy()
	end
	if manifest then
		table.clear(manifest.balloons)
		table.clear(manifest.secrets)
		table.clear(manifest.checkpoints)
		table.clear(manifest.hazards)
	end
end

-- Optional presentation helper; A's bootstrap may call it once after Build.
function WorldBuilder.ApplyLighting(lighting: Lighting)
	HubBuilder.applyLighting(content(), lighting)
end

return WorldBuilder
