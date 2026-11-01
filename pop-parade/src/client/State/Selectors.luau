--!strict
-- Pure derived values for the UI. Input: the authoritative ClientState from A (provisional shape,
-- see docs/b/CONTRACT_REQUESTS.md "ClientState fields used by B") + A's balance accessor.
-- Output: plain tables the UI renders. No Roblox APIs -> unit-tested in tests/b/unit.
--
-- Selectors never invent values: when a field is missing they return `available = false` (or nil)
-- so the UI shows a loading/unavailable state instead of fake numbers.

local Selectors = {}

export type Balance = {
	upgradeMaxLevel: (id: string) -> number?,
	upgradeCost: (id: string, level: number) -> number?, -- cost to go from `level` to `level + 1`
	upgradeValueText: (id: string, level: number) -> string?,
	speedRange: (state: any) -> { min: number, max: number }?, -- min selectable, max owned
}

local function num(x: any): number?
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return nil
end

-- XP: "Level 12 · 340 / 500 XP · 160 to next level"
function Selectors.xp(state: any): { available: boolean, level: number, current: number, needed: number, remaining: number, fraction: number, isMax: boolean }
	local level, cur, need = num(state and state.level), num(state and state.xp), num(state and state.xpNeeded)
	if not level or not cur then
		return { available = false, level = 0, current = 0, needed = 0, remaining = 0, fraction = 0, isMax = false }
	end
	if not need or need <= 0 then
		return { available = true, level = level, current = cur, needed = 0, remaining = 0, fraction = 1, isMax = true }
	end
	local c = math.clamp(cur, 0, need)
	return { available = true, level = level, current = c, needed = need, remaining = need - c, fraction = c / need, isMax = false }
end

function Selectors.coins(state: any): number?
	return num(state and state.coins)
end

-- Stage objective: only visible while in a stage. Counts UNIQUE required slots (never respawns).
function Selectors.stageProgress(state: any): { visible: boolean, done: number, total: number, fraction: number, skipped: boolean }
	local sp = state and state.stageProgress
	if not state or state.mode ~= "stage" or type(sp) ~= "table" then
		return { visible = false, done = 0, total = 0, fraction = 0, skipped = false }
	end
	local done, total = num(sp.done) or 0, num(sp.total) or 100
	local skipped = false
	if type(state.skippedStages) == "table" and sp.stageId then
		skipped = table.find(state.skippedStages, sp.stageId) ~= nil
	end
	return { visible = true, done = math.clamp(done, 0, total), total = total, fraction = if total > 0 then math.clamp(done / total, 0, 1) else 0, skipped = skipped }
end

function Selectors.hearts(state: any): { visible: boolean, current: number, max: number }
	local run = state and state.run
	if type(run) ~= "table" or (state.mode ~= "stage" and state.mode ~= "parkour") then
		return { visible = false, current = 0, max = 0 }
	end
	local max = num(run.maxHearts) or 3
	return { visible = true, current = math.clamp(num(run.hearts) or max, 0, max), max = max }
end

function Selectors.boss(state: any): { visible: boolean, id: string?, hp: number, max: number, fraction: number, phase: string? }
	local b = state and state.run and state.run.boss
	if type(b) ~= "table" or not num(b.maxHp) then
		return { visible = false, id = nil, hp = 0, max = 0, fraction = 0, phase = nil }
	end
	local max = num(b.maxHp) :: number
	local hp = math.clamp(num(b.hp) or 0, 0, max)
	return { visible = hp > 0 or b.phase == "defeated", id = b.id, hp = hp, max = max, fraction = if max > 0 then hp / max else 0, phase = b.phase }
end

function Selectors.boost(state: any): { visible: boolean, remaining: number, paused: boolean }
	local bst = state and state.boost
	local rem = num(bst and bst.remainingSeconds) or 0
	return { visible = rem > 0, remaining = rem, paused = bst ~= nil and bst.paused == true }
end

export type UpgradeRow = {
	id: string,
	available: boolean,
	level: number,
	maxLevel: number?,
	isMax: boolean,
	currentText: string?,
	nextText: string?,
	cost: number?,
	affordable: boolean,
}

function Selectors.upgrade(state: any, balance: Balance?, id: string): UpgradeRow
	local up = state and state.upgrades and state.upgrades[id]
	local level = num(type(up) == "table" and up.level or up) or 0
	if not balance or not state then
		return { id = id, available = false, level = level, maxLevel = nil, isMax = false, currentText = nil, nextText = nil, cost = nil, affordable = false }
	end
	local maxLevel = balance.upgradeMaxLevel(id)
	local isMax = maxLevel ~= nil and level >= maxLevel
	local cost = if isMax then nil else balance.upgradeCost(id, level)
	local coins = num(state.coins) or 0
	return {
		id = id,
		available = maxLevel ~= nil,
		level = level,
		maxLevel = maxLevel,
		isMax = isMax,
		currentText = balance.upgradeValueText(id, level),
		nextText = if isMax then nil else balance.upgradeValueText(id, level + 1),
		cost = cost,
		affordable = cost ~= nil and coins >= cost,
	}
end

-- First affordable upgrade (for the one-objective-at-a-time onboarding hint)
function Selectors.firstAffordableUpgrade(state: any, balance: Balance?): string?
	for _, id in { "Needle", "Attack", "Speed", "Hits", "Life" } do
		local row = Selectors.upgrade(state, balance, id)
		if row.affordable then
			return id
		end
	end
	return nil
end

-- Wheel: segments sized EXACTLY by probability. Returns degrees.
export type Segment = { itemId: string, rarity: string, probability: number, start: number, sweep: number }

function Selectors.wheelSegments(wheelTable: { any }?): ({ Segment }, boolean)
	local segs: { Segment } = {}
	if type(wheelTable) ~= "table" then
		return segs, false
	end
	local total = 0
	for _, row in wheelTable do
		local p = num(row.probability)
		if not p or p < 0 then
			return {}, false
		end
		total += p
	end
	local valid = math.abs(total - 1) < 1e-6
	if total <= 0 then
		return {}, false
	end
	local angle = 0
	for _, row in wheelTable do
		local sweep = 360 * (row.probability / total)
		table.insert(segs, { itemId = row.itemId, rarity = row.rarity, probability = row.probability, start = angle, sweep = sweep })
		angle += sweep
	end
	return segs, valid
end

-- Where the pointer should stop for an already-resolved outcome: inside the middle 60% of that
-- segment, so the animation never fakes an "almost landed on legendary" moment.
function Selectors.wheelLandingAngle(segs: { Segment }, itemId: string, rng01: number): number?
	for _, s in segs do
		if s.itemId == itemId then
			local margin = s.sweep * 0.2
			return s.start + margin + (s.sweep - 2 * margin) * math.clamp(rng01, 0, 1)
		end
	end
	return nil
end

-- Daily sign-in: 7-claim track; missing days never resets it.
function Selectors.dailyTrack(state: any, now: number): { available: boolean, claims: { { index: number, status: string } }, canClaim: boolean, nextIn: number? }
	local d = state and state.daily
	if type(d) ~= "table" then
		return { available = false, claims = {}, canClaim = false, nextIn = nil }
	end
	local claimed = num(d.claimIndex) or 0
	local claims = {}
	for i = 1, 7 do
		local status = if i <= claimed then "claimed" elseif i == claimed + 1 and d.canClaim then "ready" else "locked"
		table.insert(claims, { index = i, status = status })
	end
	local resetAt = num(d.nextResetAt)
	return { available = true, claims = claims, canClaim = d.canClaim == true and claimed < 7, nextIn = if resetAt then math.max(0, resetAt - now) else nil }
end

function Selectors.playtime(state: any): { available: boolean, minutes: number, speed: boolean, attack: boolean, needle: boolean, t15: boolean, t30: boolean }
	local d = state and state.daily
	if type(d) ~= "table" or not num(d.activeSeconds) then
		return { available = false, minutes = 0, speed = false, attack = false, needle = false, t15 = false, t30 = false }
	end
	local m = d.milestones or {}
	local t = d.tickets or {}
	return {
		available = true,
		minutes = math.floor((d.activeSeconds :: number) / 60),
		speed = m.speed == true,
		attack = m.attack == true,
		needle = m.needle == true,
		t15 = t.t15 == true,
		t30 = t.t30 == true,
	}
end

-- Offers: suppress repurchase of owned permanents; disable unavailable/unconfigured products.
function Selectors.offer(state: any, offerId: string): { visible: boolean, purchasable: boolean, owned: boolean, itemId: string?, reason: string? }
	local o = state and state.offers and state.offers[offerId]
	if type(o) ~= "table" then
		return { visible = false, purchasable = false, owned = false, itemId = nil, reason = "missing" }
	end
	local owned = o.owned == true or (o.itemId ~= nil and state.owned ~= nil and state.owned[o.itemId] == true and o.permanent ~= false)
	if owned and o.permanent ~= false then
		return { visible = false, purchasable = false, owned = true, itemId = o.itemId, reason = "owned" }
	end
	if o.available ~= true then
		return { visible = true, purchasable = false, owned = false, itemId = o.itemId, reason = "unavailable" }
	end
	return { visible = true, purchasable = true, owned = false, itemId = o.itemId, reason = nil }
end

-- Skip token: what the confirmation screen must say, and whether it can be used here.
function Selectors.skipToken(state: any): { count: number, canUse: boolean, reason: string?, stageId: string? }
	local count = num(state and state.consumables and state.consumables["consumable.skip_token"]) or 0
	local stageId = state and state.currentStageId
	if count <= 0 then
		return { count = 0, canUse = false, reason = "none", stageId = stageId }
	end
	if not stageId or state.mode ~= "stage" then
		return { count = count, canUse = false, reason = "not_in_stage", stageId = stageId }
	end
	if type(state.completedStages) == "table" and table.find(state.completedStages, stageId) then
		return { count = count, canUse = false, reason = "already_cleared", stageId = stageId }
	end
	if state.isLastAvailableStage == true then
		return { count = count, canUse = false, reason = "last_stage", stageId = stageId }
	end
	return { count = count, canUse = true, reason = nil, stageId = stageId }
end

function Selectors.journal(state: any, total: number?): { found: { string }, unknownCount: number, buffs: { speed: number, attack: number, needle: number } }
	local s = state and state.secrets or {}
	local found = {}
	for _, id in s.found or {} do
		table.insert(found, id)
	end
	table.sort(found)
	local t = num(s.total) or total or #found
	local b = s.buffs or {}
	return { found = found, unknownCount = math.max(0, t - #found), buffs = { speed = num(b.speed) or 0, attack = num(b.attack) or 0, needle = num(b.needle) or 0 } }
end

return Selectors
