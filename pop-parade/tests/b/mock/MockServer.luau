--!strict
-- TEST-ONLY in-memory server so B can exercise the client before A's systems exist.
-- Pure Luau (no Roblox APIs): driven by MockTransport in Studio previews and directly by unit tests.
-- It imitates the CONTRACT SHAPES, not A's real rules. Everything it awards is fake and unsaved,
-- and the preview shows a permanent "TEST PREVIEW" banner while it runs.

local Fixtures = require(script.Parent.Fixtures)
local MockBalance = require(script.Parent.MockBalance)

local MockServer = {}
MockServer.__index = MockServer

local HP_BY_TIER: { [string]: number } = {
	["hub.practice"] = 5,
	["rubber.t1"] = 5,
	["rubber.t2"] = 10,
	["rubber.t3"] = 15,
	["rubber.bonus"] = 10,
	["parkour.side"] = 5,
}
local REWARD_BY_TIER: { [string]: { coins: number, xp: number } } = {
	["hub.practice"] = { coins = 1, xp = 2 },
	["rubber.t1"] = { coins = 2, xp = 3 },
	["rubber.t2"] = { coins = 3, xp = 4 },
	["rubber.t3"] = { coins = 4, xp = 5 },
	["rubber.bonus"] = { coins = 8, xp = 6 },
	["parkour.side"] = { coins = 2, xp = 2 },
}

export type Sink = {
	actionResult: (msg: any) -> (),
	stateUpdate: (msg: any) -> (),
	worldUpdate: (msg: any) -> (),
}

function MockServer.new(opts: { fixture: string, now: number, userId: number, balloonDefs: { any }, seed: number? })
	local self = setmetatable({
		state = Fixtures.get(opts.fixture, opts.now),
		now = opts.now,
		userId = opts.userId,
		revision = 0,
		sequence = 0,
		defs = {} :: { [string]: any },
		balloons = {} :: { [string]: any },
		uniqueRequired = {} :: { [string]: boolean },
		spins = {} :: { [string]: any },
		processed = {} :: { [string]: any },
		sink = nil :: Sink?,
		rng = opts.seed or 12345,
		pendingEvents = {} :: { any },
		boss = nil :: any,
	}, MockServer)
	for _, d in opts.balloonDefs do
		self.defs[d.id] = d
	end
	self:_resetBalloons()
	return self
end

function MockServer._rand(self: any): number
	-- LCG; deterministic so tests are stable
	self.rng = (self.rng * 1103515245 + 12345) % 2147483648
	return self.rng / 2147483648
end

function MockServer._zoneOf(self: any): string
	local s = self.state
	if s.mode == "stage" then
		return s.currentStageId or "stage.hub"
	elseif s.mode == "parkour" then
		return "parkour.001"
	end
	return "stage.hub"
end

function MockServer._resetBalloons(self: any)
	table.clear(self.balloons)
	local zone = self:_zoneOf()
	for id, d in self.defs do
		if d.stageId == zone then
			local hp = HP_BY_TIER[d.tierKey] or 5
			self.balloons[id] = { slotId = id, generation = 0, state = "Active", hp = hp, maxHp = hp, respawnAt = nil }
		end
	end
end

function MockServer.attach(self: any, sink: Sink)
	self.sink = sink
end

function MockServer._pushState(self: any)
	self.revision += 1
	if self.sink then
		self.sink.stateUpdate({ v = 1, revision = self.revision, serverTime = self.now, state = table.clone(self.state) })
	end
end

function MockServer._worldMessage(self: any, snapshot: boolean, balloons: { any }, events: { any }): any
	self.sequence += 1
	return { v = 1, sequence = self.sequence, stageId = self:_zoneOf(), snapshot = if snapshot then true else nil, balloons = balloons, events = events }
end

function MockServer._pushWorld(self: any, balloons: { any }, events: { any })
	if self.sink and (#balloons > 0 or #events > 0) then
		self.sink.worldUpdate(self:_worldMessage(false, balloons, events))
	end
end

function MockServer.snapshotMessage(self: any): any
	local list = {}
	for _, b in self.balloons do
		table.insert(list, table.clone(b))
	end
	table.sort(list, function(a: any, b: any): boolean
		return a.slotId < b.slotId
	end)
	return self:_worldMessage(true, list, {})
end

local function result(requestId: string, ok: boolean, code: string?, data: any?): any
	return { v = 1, requestId = requestId, ok = ok, code = code, data = data }
end

function MockServer.handle(self: any, env: any): any
	if type(env) ~= "table" or env.v ~= 1 or type(env.requestId) ~= "string" then
		return nil
	end
	-- idempotency for grant-like actions
	if self.processed[env.requestId] then
		return self.processed[env.requestId]
	end
	local res = self:_dispatch(env)
	local idempotent = { RequestSpin = true, ClaimDaily = true, ConsumeItem = true, UseSkipToken = true, BuyUpgrade = true, RequestPurchase = true }
	if idempotent[env.action] then
		self.processed[env.requestId] = res
	end
	return res
end

function MockServer.receive(self: any, env: any)
	local res = self:handle(env)
	if res and self.sink then
		self.sink.actionResult(res)
	end
end

function MockServer._dispatch(self: any, env: any): any
	local s = self.state
	local a, p, id = env.action, env.payload or {}, env.requestId
	if a == "GetState" then
		self.revision += 1
		return result(id, true, nil, { revision = self.revision, serverTime = self.now, state = table.clone(s) })
	elseif a == "GetWorldSnapshot" then
		return result(id, true, nil, self:snapshotMessage())
	elseif a == "BuyUpgrade" then
		local up = s.upgrades[p.upgradeId]
		if not up then
			return result(id, false, "INVALID_REQUEST")
		end
		local cost = MockBalance.upgradeCost(p.upgradeId, up.level)
		if not cost then
			return result(id, false, "LOCKED")
		end
		if s.coins < cost then
			return result(id, false, "INSUFFICIENT_FUNDS")
		end
		s.coins -= cost
		up.level += 1
		if p.upgradeId == "Speed" then
			s.stats.moveSpeedMax = 16 + up.level
		elseif p.upgradeId == "Needle" then
			s.stats.damage = 5 + up.level * 3
		elseif p.upgradeId == "Life" then
			s.stats.maxHearts = 3 + up.level
		elseif p.upgradeId == "Hits" then
			s.stats.targets = 1 + up.level
		elseif p.upgradeId == "Attack" then
			s.stats.attacksPerSecond = 2 + up.level * 0.06
		end
		self:_pushState()
		return result(id, true, nil, { upgradeId = p.upgradeId, level = up.level })
	elseif a == "SetMoveSpeed" then
		if type(p.speed) ~= "number" then
			return result(id, false, "INVALID_REQUEST")
		end
		s.selectedSpeed = math.clamp(math.floor(p.speed), 12, s.stats.moveSpeedMax)
		self:_pushState()
		return result(id, true, nil, { speed = s.selectedSpeed })
	elseif a == "EquipItem" then
		if p.itemId ~= nil and not s.owned[p.itemId] then
			return result(id, false, "NOT_OWNED")
		end
		s.equipped[p.slot] = p.itemId
		self:_pushState()
		return result(id, true)
	elseif a == "SetSetting" then
		if s.settings[p.key] == nil then
			return result(id, false, "INVALID_REQUEST")
		end
		s.settings[p.key] = p.value
		self:_pushState()
		return result(id, true)
	elseif a == "EnterStage" then
		if p.stageId ~= "stage.rubber.001" then
			return result(id, false, "LOCKED")
		end
		s.mode = "stage"
		s.currentStageId = p.stageId
		s.stageProgress = s.stageProgress or { stageId = p.stageId, done = 0, total = 100 }
		s.run = { hearts = s.stats.maxHearts, maxHearts = s.stats.maxHearts, checkpointId = "cp.rubber.001.01" }
		self:_resetBalloons()
		self:_pushState()
		return result(id, true)
	elseif a == "EnterMode" then
		if p.mode ~= "hub" and p.mode ~= "parkour" then
			return result(id, false, "INVALID_REQUEST")
		end
		s.mode = p.mode
		s.currentStageId = nil
		s.run = if p.mode == "parkour" then { hearts = 3, maxHearts = 3, checkpointId = "cp.parkour.001.01" } else nil
		self:_resetBalloons()
		self:_pushState()
		return result(id, true)
	elseif a == "RestartRun" then
		if s.run then
			s.run.hearts = s.run.maxHearts
		end
		self:_pushState()
		return result(id, true)
	elseif a == "ClaimDaily" then
		if not s.daily.canClaim then
			return result(id, false, "ALREADY_CLAIMED")
		end
		s.daily.claimIndex = math.min(7, s.daily.claimIndex + 1)
		s.daily.canClaim = false
		s.spinTickets += 1
		s.coins += 25
		local cosmetic = nil
		if s.daily.claimIndex == 7 then
			cosmetic = "popfx.streamers"
			s.owned[cosmetic] = true
		end
		self:_pushState()
		return result(id, true, nil, { claimIndex = s.daily.claimIndex, tickets = 1, coins = 25, itemId = cosmetic })
	elseif a == "RequestSpin" then
		if s.spinTickets <= 0 then
			return result(id, false, "UNAVAILABLE")
		end
		s.spinTickets -= 1
		local roll = self:_rand()
		local acc, chosen = 0, s.wheel.table[1]
		for _, row in s.wheel.table do
			acc += row.probability
			if roll < acc then
				chosen = row
				break
			end
		end
		local duplicate = s.owned[chosen.itemId] == true
		local coins = 0
		if duplicate then
			coins = s.wheel.duplicateCoins[chosen.rarity] or 0
			s.coins += coins
		else
			s.owned[chosen.itemId] = true
		end
		s.spinsCompleted += 1
		local founder = false
		if s.spinsCompleted >= s.founderSpinsRequired and not s.owned["skin.wheel_founder"] then
			s.owned["skin.wheel_founder"] = true
			founder = true
		end
		local outcome = { spinId = id, itemId = chosen.itemId, rarity = chosen.rarity, duplicate = duplicate, coins = coins, founderGranted = founder }
		s.pendingSpin = outcome
		self:_pushState()
		self:_pushWorld({}, { { type = "WheelResult", requestId = id, itemId = chosen.itemId, rarity = chosen.rarity, duplicate = duplicate, coins = coins } })
		return result(id, true, nil, outcome)
	elseif a == "ConsumeItem" then
		local count = s.consumables[p.itemId] or 0
		if count <= 0 then
			return result(id, false, "NOT_OWNED")
		end
		if p.itemId == "consumable.double_xp" then
			if s.boost.remainingSeconds + 600 > s.boost.capSeconds then
				return result(id, false, "LOCKED")
			end
			s.boost.remainingSeconds += 600
		else
			return result(id, false, "INVALID_REQUEST")
		end
		s.consumables[p.itemId] = count - 1
		self:_pushState()
		return result(id, true, nil, { remainingSeconds = s.boost.remainingSeconds })
	elseif a == "UseSkipToken" then
		if (s.consumables["consumable.skip_token"] or 0) <= 0 then
			return result(id, false, "NOT_OWNED")
		end
		if s.isLastAvailableStage then
			return result(id, false, "LOCKED")
		end
		s.consumables["consumable.skip_token"] -= 1
		table.insert(s.skippedStages, p.stageId)
		self:_pushState()
		return result(id, true, nil, { skippedStageId = p.stageId })
	elseif a == "RequestPurchase" then
		local o = s.offers[p.offerId]
		if not o or not o.available then
			return result(id, false, "UNAVAILABLE")
		end
		if o.permanent and s.owned[o.itemId] then
			return result(id, false, "ALREADY_CLAIMED")
		end
		-- mock: there is no real product, so the client must not open a platform prompt
		return result(id, true, nil, { purchaseType = if o.kind == "pass" then "GamePass" else "DeveloperProduct", id = nil, mock = true })
	elseif a == "RequestExtraJump" then
		if s.mode == "parkour" or s.equipped.Wings ~= nil then
			return result(id, true, nil, { granted = true })
		end
		return result(id, false, "NOT_OWNED")
	end
	return result(id, false, "INVALID_REQUEST")
end

-- Simulated auto-attack against a chosen slot (MockTransport picks the nearest target).
function MockServer.attack(self: any, slotId: string)
	local b = self.balloons[slotId]
	local d = self.defs[slotId]
	if not b or not d or b.state ~= "Active" then
		return
	end
	local dmg = self.state.stats.damage
	local applied = math.min(dmg, b.hp)
	b.hp -= applied
	local events: { any } = { { type = "Damage", sourceUserId = self.userId, slotId = slotId, generation = b.generation, amount = applied } }
	if b.hp <= 0 then
		b.state = "Popped"
		b.respawnAt = self.now + d.respawnSeconds
		table.insert(events, { type = "Pop", slotId = slotId, generation = b.generation, sourceUserId = self.userId })
		local reward = REWARD_BY_TIER[d.tierKey] or { coins = 1, xp = 1 }
		local s = self.state
		s.coins += reward.coins
		local xpGain = reward.xp * (if s.boost.remainingSeconds > 0 then 2 else 1)
		s.xp += xpGain
		while s.xp >= s.xpNeeded do
			s.xp -= s.xpNeeded
			s.level += 1
			s.xpNeeded = math.floor(s.xpNeeded * 1.25)
		end
		if d.required and not self.uniqueRequired[slotId] and s.stageProgress then
			self.uniqueRequired[slotId] = true
			s.stageProgress.done = math.min(s.stageProgress.total, s.stageProgress.done + 1)
		end
		self:_pushState()
	end
	self:_pushWorld({ table.clone(b) }, events)
end

function MockServer.tick(self: any, now: number)
	self.now = now
	local changed, events = {}, {}
	for id, b in self.balloons do
		if b.state == "Popped" and b.respawnAt and now >= b.respawnAt then
			b.generation += 1
			b.state = "Active"
			b.hp = b.maxHp
			b.respawnAt = nil
			table.insert(changed, table.clone(b))
			table.insert(events, { type = "Inflate", slotId = id, generation = b.generation })
		end
	end
	if #changed > 0 then
		table.sort(changed, function(x: any, y: any): boolean
			return x.slotId < y.slotId
		end)
		table.sort(events, function(x: any, y: any): boolean
			return x.slotId < y.slotId
		end)
		self:_pushWorld(changed, events)
	end
end

-- Test helper: drop a world update to simulate packet loss / missed update.
function MockServer.skipSequence(self: any)
	self.sequence += 1
end

return MockServer
