--!strict
-- PROVISIONAL B-side types for layout data and the WorldManifest.
--
-- The integration contract says A writes the canonical typed definitions in
-- src/shared/contracts/** during the foundation commit. That commit does not exist yet, so these
-- types live in a B-owned folder and are clearly provisional. When A's contract lands:
--   1. Replace these with re-exports of A's types (or delete them), and
--   2. Fix every field mismatch on B's side rather than editing A's files.
-- Every field below is listed in docs/b/CONTRACT_REQUESTS.md for A to confirm or change.

export type Vec3 = { x: number, y: number, z: number }

-- Pure layout transform: position + yaw (degrees, rotation about +Y). Converted to CFrame by builders.
export type Placement = { pos: Vec3, yaw: number }

export type BalloonLayout = {
	id: string, -- balloon.rubber.001.037
	stageId: string,
	routeId: string,
	sectionIndex: number,
	required: boolean,
	pos: Vec3, -- logical (authoritative) centre; cosmetic bobbing is never applied to this
	hitRadius: number,
	material: string,
	theme: string,
	colorStep: number, -- 0..999
	tierKey: string, -- A maps to HP/rewards
	respawnSeconds: number, -- 3..5
}

export type RouteLayout = {
	id: string, -- route.rubber.001.s3.left
	stageId: string,
	sectionIndex: number,
	lane: string, -- "single" | "left" | "center" | "right"
	optional: boolean,
}

export type CheckpointLayout = {
	id: string, -- cp.rubber.001.02
	stageId: string,
	order: number,
	placement: Placement,
	size: Vec3, -- trigger volume
	sectionIndex: number,
}

export type HazardLayout = {
	id: string, -- hazard.rubber.001.s3.sweeper.1
	stageId: string,
	behaviorKey: string, -- "sweeper" | "puff_vent" | "tack_mat" (A runs the behaviour)
	placement: Placement,
	shape: { kind: "box" | "cylinder", size: Vec3 },
	params: { [string]: number },
	checkpointId: string, -- where a player returns after a hit/fall in this hazard's section
}

export type BossLayout = {
	id: string,
	stageId: string,
	behaviorKey: string,
	anchor: Placement, -- boss centre
	arenaCenter: Vec3,
	arenaRadius: number,
	params: { [string]: number },
	checkpointId: string,
	weakPointOffset: Vec3, -- exposed-knot location relative to anchor (visual + A hit volume)
}

export type PlatformLayout = {
	id: string,
	kind: "floor" | "ramp" | "bridge" | "step" | "wall" | "rail" | "ledge",
	placement: Placement,
	size: Vec3,
	pitch: number?, -- degrees, for ramps
	color: string, -- "floor" | "trim" | "accent" | "lane:<n>"
	sectionIndex: number?,
}

export type StageLayout = {
	id: string,
	theme: string,
	material: string,
	displayKey: string,
	nextStageId: string?,
	bounds: { min: Vec3, max: Vec3 },
	start: Placement,
	replayStart: Placement,
	routes: { RouteLayout },
	checkpoints: { CheckpointLayout },
	balloons: { BalloonLayout },
	hazards: { HazardLayout },
	boss: BossLayout,
	platforms: { PlatformLayout },
	requiredSlotIds: { string },
	allowedShortcuts: { string },
}

export type ParkourLayout = {
	id: string,
	displayKey: string,
	start: Placement,
	finish: Placement, -- end marker
	bounds: { min: Vec3, max: Vec3 },
	checkpoints: { CheckpointLayout },
	platforms: { PlatformLayout },
	shortcut: { id: string, fromCheckpoint: string, toCheckpoint: string, note: string },
	jumpExpectations: { maxGap: number, maxRise: number, needsExtraJump: boolean, note: string },
	sideBalloons: { BalloonLayout }, -- beside the path, never supporting platforms
}

export type DecorMarker = {
	id: string,
	kind: string, -- "kiosk.upgrades" | "display.cosmetics" | "wheel" | "rewards" | "afk.free" | "afk.premium" | "gate.stage" | "gate.parkour" | "sign"
	placement: Placement,
	radius: number, -- interaction radius for client UI hints
	data: { [string]: any }?, -- string | number | boolean values
}

export type AfkStationLayout = {
	id: string, -- afk.hub.free.01
	tier: "free" | "premium",
	placement: Placement, -- where the player stands
	balloonPos: Vec3, -- giant station balloon centre
	radius: number,
}

return {}
