--!strict
-- TEST-ONLY ClientState fixtures (provisional shape; see docs/b/CONTRACT_REQUESTS.md).
-- Covers every fixture the contract asks A to supply so B's UI can be exercised before A's real
-- fixtures exist. When A's fixtures land, these are replaced by (or adapted to) A's.
-- Never loaded by a production build: tests/b is only mapped in preview-b.project.json.

local Fixtures = {}

local DAY = 86400

local WHEEL_TABLE = {
	{ itemId = "skin.rubber_twist", rarity = "Common", probability = 0.70 },
	{ itemId = "skin.candy_swirl", rarity = "Uncommon", probability = 0.23 },
	{ itemId = "skin.chrome_spiral", rarity = "Rare", probability = 0.06 },
	{ itemId = "skin.neon_helix", rarity = "Epic", probability = 0.009 },
	{ itemId = "skin.prism_crown", rarity = "Legendary", probability = 0.001 },
}

local function base(now: number): any
	local nextReset = (math.floor(now / DAY) + 1) * DAY
	return {
		schemaVersion = 1,
		coins = 0,
		xp = 0,
		xpNeeded = 50,
		level = 1,
		upgrades = { Needle = { level = 0 }, Speed = { level = 0 }, Attack = { level = 0 }, Hits = { level = 0 }, Life = { level = 0 } },
		stats = { damage = 5, attacksPerSecond = 2, moveSpeedMax = 16, reach = 6, targets = 1, maxHearts = 3 },
		selectedSpeed = 16,
		mode = "hub",
		currentStageId = nil,
		stageProgress = nil,
		completedStages = {},
		skippedStages = {},
		isLastAvailableStage = true,
		equipped = { NeedleSkin = "skin.default", Sound = "sound.classic_pop", PopEffect = "popfx.confetti" },
		owned = { ["skin.default"] = true, ["sound.classic_pop"] = true, ["sound.soft_bubble"] = true, ["sound.rubber_snap"] = true, ["sound.squeak"] = true, ["sound.tiny_firework"] = true, ["popfx.confetti"] = true },
		consumables = { ["consumable.skip_token"] = 0, ["consumable.double_xp"] = 0 },
		daily = {
			claimIndex = 0,
			canClaim = true,
			nextResetAt = nextReset,
			activeSeconds = 0,
			milestones = { speed = false, attack = false, needle = false },
			tickets = { t15 = false, t30 = false },
		},
		secrets = { found = {}, total = 3, buffs = { speed = 0, attack = 0, needle = 0 } },
		spinTickets = 1,
		spinsCompleted = 0,
		founderSpinsRequired = 25,
		pendingSpin = nil,
		wheel = { table = WHEEL_TABLE, duplicateCoins = { Common = 25, Uncommon = 60, Rare = 150, Epic = 400, Legendary = 1000 } },
		boost = { remainingSeconds = 0, paused = false, capSeconds = 3600 },
		shop = { rotationId = "rot." .. math.floor(now / DAY), refreshAt = nextReset, featured = { "offer.skin.candy_swirl", "offer.trail.rainbow_deluxe", "offer.wings.ornate" }, collection = { "offer.skin.rubber_twist", "offer.skin.candy_swirl", "offer.skin.chrome_spiral", "offer.skin.neon_helix", "offer.skin.prism_crown", "offer.trail.rainbow_deluxe", "offer.trail.rocket_deluxe", "offer.trail.neon_deluxe", "offer.wings.ornate", "offer.consumable.skip_token", "offer.consumable.double_xp", "offer.soundpack.party" } },
		offers = {
			["offer.skin.rubber_twist"] = { itemId = "skin.rubber_twist", kind = "pass", available = true, permanent = true },
			["offer.skin.candy_swirl"] = { itemId = "skin.candy_swirl", kind = "pass", available = true, permanent = true },
			["offer.skin.chrome_spiral"] = { itemId = "skin.chrome_spiral", kind = "pass", available = true, permanent = true },
			["offer.skin.neon_helix"] = { itemId = "skin.neon_helix", kind = "pass", available = true, permanent = true },
			["offer.skin.prism_crown"] = { itemId = "skin.prism_crown", kind = "pass", available = true, permanent = true },
			["offer.trail.rainbow_deluxe"] = { itemId = "trail.rainbow_deluxe", kind = "pass", available = true, permanent = true },
			["offer.trail.rocket_deluxe"] = { itemId = "trail.rocket_deluxe", kind = "pass", available = true, permanent = true },
			["offer.trail.neon_deluxe"] = { itemId = "trail.neon_deluxe", kind = "pass", available = true, permanent = true },
			["offer.wings.ornate"] = { itemId = "wings.ornate", kind = "pass", available = true, permanent = true },
			["offer.consumable.skip_token"] = { itemId = "consumable.skip_token", kind = "product", available = false, permanent = false }, -- product ID not configured yet
			["offer.consumable.double_xp"] = { itemId = "consumable.double_xp", kind = "product", available = true, permanent = false },
			["offer.soundpack.party"] = { itemId = "sound.kazoo_toot", kind = "pass", available = true, permanent = true },
		},
		settings = { music = 0.5, sfx = 0.8, reducedEffects = false, shake = true, dof = true, bloom = true, sunRays = true, shadows = true },
		run = nil,
	}
end

Fixtures.WHEEL_TABLE = WHEEL_TABLE

function Fixtures.newPlayer(now: number): any
	return base(now)
end

function Fixtures.wealthyPlayer(now: number): any
	local s = base(now)
	s.coins = 2500000
	s.level = 42
	s.xp = 7300
	s.xpNeeded = 12000
	s.upgrades = { Needle = { level = 24 }, Speed = { level = 10 }, Attack = { level = 18 }, Hits = { level = 2 }, Life = { level = 2 } }
	s.stats = { damage = 180, attacksPerSecond = 3.6, moveSpeedMax = 26, reach = 6, targets = 3, maxHearts = 5 }
	s.selectedSpeed = 22
	s.completedStages = { "stage.rubber.001" }
	s.owned["wings.basic"] = true
	s.owned["trail.rainbow"] = true
	s.owned["skin.rubber_twist"] = true
	s.owned["skin.chrome_spiral"] = true
	s.owned["accessory.zoom_sneakers"] = true
	s.equipped.Wings = "wings.basic"
	s.equipped.Trail = "trail.rainbow"
	s.equipped.Accessory = "accessory.zoom_sneakers"
	s.accessoryBonuses = { ["accessory.zoom_sneakers"] = "+3% speed", ["accessory.focus_goggles"] = "+3% attack speed", ["accessory.sharp_glove"] = "+3% needle damage" }
	s.consumables["consumable.double_xp"] = 2
	s.spinTickets = 3
	s.spinsCompleted = 24
	return s
end

function Fixtures.stageAt99(now: number): any
	local s = base(now)
	s.coins = 340
	s.level = 6
	s.xp = 120
	s.xpNeeded = 210
	s.mode = "stage"
	s.currentStageId = "stage.rubber.001"
	s.stageProgress = { stageId = "stage.rubber.001", done = 99, total = 100 }
	s.run = { hearts = 2, maxHearts = 3, checkpointId = "cp.rubber.001.05" }
	return s
end

function Fixtures.boss(now: number): any
	local s = Fixtures.stageAt99(now)
	s.stageProgress.done = 100
	s.run = { hearts = 3, maxHearts = 3, checkpointId = "cp.rubber.001.06", boss = { id = "boss.king_puffer", hp = 620, maxHp = 900, phase = "windup" } }
	return s
end

function Fixtures.activeMinutes(now: number, minutes: number): any
	local s = base(now)
	s.daily.activeSeconds = minutes * 60
	s.daily.milestones = { speed = minutes >= 10, attack = minutes >= 20, needle = minutes >= 30 }
	s.daily.tickets = { t15 = minutes >= 15, t30 = minutes >= 30 }
	return s
end

function Fixtures.utcRollover(now: number): any
	local s = base(now)
	s.daily.nextResetAt = now + 5 -- five seconds before reset
	s.daily.claimIndex = 3
	s.daily.canClaim = false
	return s
end

function Fixtures.secrets(now: number): any
	local s = base(now)
	s.secrets = { found = { "secret.hub.big_top" }, total = 3, buffs = { speed = 0, attack = 1, needle = 0 } }
	return s
end

function Fixtures.skipToken(now: number): any
	local s = Fixtures.stageAt99(now)
	s.stageProgress.done = 12
	s.consumables["consumable.skip_token"] = 1
	s.isLastAvailableStage = false
	return s
end

function Fixtures.boostActive(now: number): any
	local s = base(now)
	s.boost = { remainingSeconds = 437, paused = false, capSeconds = 3600 }
	s.consumables["consumable.double_xp"] = 1
	return s
end

function Fixtures.boostExpired(now: number): any
	local s = base(now)
	s.boost = { remainingSeconds = 0, paused = false, capSeconds = 3600 }
	return s
end

function Fixtures.missingProducts(now: number): any
	local s = base(now)
	for _, o in s.offers do
		o.available = false
	end
	return s
end

function Fixtures.delayedPurchase(now: number): any
	local s = base(now)
	s.pendingPurchases = { "offer.consumable.double_xp" }
	return s
end

Fixtures.LIST = {
	"newPlayer",
	"wealthyPlayer",
	"stageAt99",
	"boss",
	"activeMinutes9",
	"activeMinutes10",
	"activeMinutes20",
	"activeMinutes30",
	"utcRollover",
	"secrets",
	"skipToken",
	"boostActive",
	"boostExpired",
	"missingProducts",
	"delayedPurchase",
}

function Fixtures.get(name: string, now: number): any
	local m = string.match(name, "^activeMinutes(%d+)$")
	if m then
		return Fixtures.activeMinutes(now, tonumber(m) :: number)
	end
	local f = (Fixtures :: any)[name]
	assert(type(f) == "function", "unknown fixture " .. name)
	return f(now)
end

return Fixtures
