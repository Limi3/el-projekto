local Env = require(script.Parent.Env)
local root = script.Parent.Parent -- TestsB
local Protocol = require(Env.Client.GameClient.Protocol)
local GameClient = require(Env.Client.GameClient)
local Selectors = require(Env.Client.State.Selectors)
local Format = require(Env.Client.Util.Format)
local Pool = require(Env.Client.Util.Pool)
local MockServer = require(root.mock.MockServer)
local Loopback = require(root.mock.LoopbackTransport)
local MockBalance = require(root.mock.MockBalance)
local Fixtures = require(root.mock.Fixtures)
local Hub = require(Env.Content.Layouts.Hub)
local Rubber = require(Env.Content.Layouts.RubberStage001)

local NOW = 1793548800 -- fixed epoch for deterministic fixtures

local function defs()
	local list = {}
	for _, b in Hub.get().practice do
		table.insert(list, b)
	end
	for _, b in Rubber.get().balloons do
		table.insert(list, b)
	end
	return list
end

local function setup(fixture)
	local clock = { t = 100 }
	local server = MockServer.new({ fixture = fixture or "newPlayer", now = NOW, userId = 1, balloonDefs = defs() })
	local transport = Loopback.new(server)
	local client = GameClient.new(transport, {
		clock = function()
			return clock.t
		end,
		session = "test",
		timeout = 5,
	})
	return client, server, transport, clock
end

return {
	Protocol = {
		["envelopes only allow contract actions"] = function(t)
			local env = Protocol.makeEnvelope("s-1", "BuyUpgrade", { upgradeId = "Needle" })
			t.eq(env.v, 1)
			t.eq(env.action, "BuyUpgrade")
			t.ok(not pcall(Protocol.makeEnvelope, "s-2", "GrantCoins", {}), "GrantCoins is not an action")
			t.ok(not pcall(Protocol.makeEnvelope, string.rep("x", 41), "GetState", {}), "request id length bounded")
		end,
		["stale and wrong-schema states are ignored"] = function(t)
			local tr = Protocol.newRevisionTracker()
			t.ok(Protocol.acceptState(tr, { v = 1, revision = 5, state = {} }), "first")
			t.ok(not Protocol.acceptState(tr, { v = 1, revision = 5, state = {} }), "same revision")
			t.ok(not Protocol.acceptState(tr, { v = 1, revision = 4, state = {} }), "older")
			local ok, why = Protocol.acceptState(tr, { v = 2, revision = 9, state = {} })
			t.ok(not ok, "schema 2 rejected")
			t.eq(why, "schema")
			t.ok(Protocol.acceptState(tr, { v = 1, revision = 6, state = {} }), "newer")
		end,
		["world sequence gaps require a snapshot"] = function(t)
			local tr = Protocol.newSequenceTracker()
			t.eq(Protocol.classifyWorld(tr, { v = 1, sequence = 3 }), "gap", "delta before first snapshot")
			t.eq(Protocol.classifyWorld(tr, { v = 1, sequence = 4, snapshot = true }), "apply")
			t.eq(Protocol.classifyWorld(tr, { v = 1, sequence = 5 }), "apply")
			t.eq(Protocol.classifyWorld(tr, { v = 1, sequence = 5 }), "stale")
			t.eq(Protocol.classifyWorld(tr, { v = 1, sequence = 7 }), "gap")
			t.eq(Protocol.classifyWorld(tr, { v = 1, sequence = 8 }), "gap", "still waiting for snapshot")
			t.eq(Protocol.classifyWorld(tr, { v = 1, sequence = 9, snapshot = true }), "apply")
		end,
		["pop/inflate processed once per generation"] = function(t)
			local g = Protocol.newGenerationTracker()
			t.ok(Protocol.applyBalloonEvent(g, "b1", 0, "Pop"), "pop gen0")
			t.ok(not Protocol.applyBalloonEvent(g, "b1", 0, "Pop"), "duplicate pop")
			t.ok(Protocol.applyBalloonEvent(g, "b1", 1, "Inflate"), "inflate gen1")
			t.ok(not Protocol.applyBalloonEvent(g, "b1", 0, "Pop"), "late pop of old gen ignored")
			t.ok(not Protocol.applyBalloonEvent(g, "b1", 1, "Inflate"), "duplicate inflate")
			t.ok(Protocol.applyBalloonEvent(g, "b1", 1, "Pop"), "pop gen1")
		end,
	},

	GameClient = {
		["connects listeners before the first request"] = function(t)
			local client, server, transport = setup()
			local connectedBeforeSend = nil
			local origConnect, origSend = transport.connect, transport.send
			local connected = false
			transport.connect = function(self, h)
				connected = true
				return origConnect(self, h)
			end
			transport.send = function(self, env)
				if connectedBeforeSend == nil then
					connectedBeforeSend = connected
				end
				return origSend(self, env)
			end
			client:start()
			t.eq(connectedBeforeSend, true)
			t.eq(client.status, "ready")
			t.ok(client.state ~= nil and client.state.coins == 0, "state from server")
		end,
		["popping updates state; balloon events fire once"] = function(t)
			local client, server = setup()
			client:start()
			local pops, inflates = 0, 0
			client.WorldEvent:Connect(function(ev)
				if ev.type == "Pop" then
					pops += 1
				elseif ev.type == "Inflate" then
					inflates += 1
				end
			end)
			server:attack("balloon.hub.practice.01")
			t.eq(pops, 1)
			t.ok(client.state.coins > 0, "coins from authoritative state")
			server:attack("balloon.hub.practice.01") -- already popped: nothing
			t.eq(pops, 1)
			server:tick(NOW + 10)
			t.eq(inflates, 1, "reinflated")
			t.eq(client.balloonStates["balloon.hub.practice.01"].generation, 1)
		end,
		["missed world update triggers snapshot resync"] = function(t)
			local client, server, transport = setup()
			client:start()
			local snapshots = 0
			client.WorldSnapshot:Connect(function()
				snapshots += 1
			end)
			transport.dropNextWorld = true
			server:attack("balloon.hub.practice.02")
			server:attack("balloon.hub.practice.03") -- arrives with a gap -> snapshot
			t.eq(snapshots, 1, "resynced via snapshot")
			t.eq(client.balloonStates["balloon.hub.practice.02"].state, "Popped", "snapshot carried the missed pop")
		end,
		["timeouts report TIMEOUT and late spin results are recovered, not rerolled"] = function(t)
			local client, server, transport, clock = setup()
			client:start()
			transport.available = true
			-- swallow the next action result to simulate a lost reply
			local origReceive = server.receive
			local held = nil
			server.receive = function(self, env)
				held = env
				self:handle(env) -- server resolves and records the outcome
			end
			local got = nil
			local id = client:request("RequestSpin", {}, function(r)
				got = r
			end)
			clock.t += 6
			client:tick()
			t.eq(got and got.code, "TIMEOUT")
			local ticketsAfter = server.state.spinTickets
			-- retry with the SAME request id: server returns the same outcome, no new ticket spent
			server.receive = origReceive
			local again = nil
			client:request("RequestSpin", {}, function(r)
				again = r
			end, id)
			t.ok(again and again.ok, "retry ok")
			t.eq(server.state.spinTickets, ticketsAfter, "no second ticket spent")
			t.eq(again.data.spinId, id)
			t.ok(held ~= nil, "original request reached the server")
		end,
		["unavailable server never produces fake state"] = function(t)
			local client, server, transport = setup()
			transport.available = false
			client:start()
			t.eq(client.status, "unavailable")
			t.eq(client.state, nil)
			local r = nil
			client:request("BuyUpgrade", { upgradeId = "Needle" }, function(x)
				r = x
			end)
			t.eq(r.ok, false)
			t.eq(r.code, "NOT_READY")
		end,
		["required slots count once even after respawn"] = function(t)
			local client, server = setup("stageAt99")
			client:start()
			client:request("EnterStage", { stageId = "stage.rubber.001" })
			server.state.stageProgress.done = 10
			server:attack("balloon.rubber.001.001")
			t.eq(client.state.stageProgress.done, 11)
			server:tick(NOW + 10)
			server:attack("balloon.rubber.001.001")
			t.eq(client.state.stageProgress.done, 11, "respawned balloon pays rewards but not objective")
		end,
	},

	Selectors = {
		["xp line matches the spec example"] = function(t)
			local x = Selectors.xp({ level = 12, xp = 340, xpNeeded = 500 })
			t.eq(x.level, 12)
			t.eq(x.current, 340)
			t.eq(x.needed, 500)
			t.eq(x.remaining, 160)
			t.ok(not Selectors.xp({}).available, "missing fields -> unavailable, not zero")
		end,
		["upgrade rows show current/next/cost/max"] = function(t)
			local s = Fixtures.newPlayer(NOW)
			s.coins = 15
			local row = Selectors.upgrade(s, MockBalance, "Needle")
			t.eq(row.level, 0)
			t.eq(row.cost, 10)
			t.ok(row.affordable)
			t.eq(row.currentText, "5 dmg")
			t.eq(row.nextText, "8 dmg")
			s.upgrades.Hits.level = 2
			local hits = Selectors.upgrade(s, MockBalance, "Hits")
			t.ok(hits.isMax, "Hits capped at 3 targets")
			t.eq(hits.cost, nil)
			t.ok(not Selectors.upgrade(s, nil, "Needle").available, "no balance -> unavailable")
		end,
		["wheel slices are exactly proportional and landing stays inside"] = function(t)
			local segs, valid = Selectors.wheelSegments(Fixtures.WHEEL_TABLE)
			t.ok(valid, "probabilities total 100%")
			t.near(segs[1].sweep, 252, 1e-9, "70% = 252 degrees")
			t.near(segs[5].sweep, 0.36, 1e-9, "0.1% = 0.36 degrees (not inflated)")
			for _, r in { 0, 0.5, 1 } do
				local a = Selectors.wheelLandingAngle(segs, "skin.chrome_spiral", r)
				t.ok(a > segs[3].start and a < segs[3].start + segs[3].sweep, "inside its slice")
				t.ok(a >= segs[3].start + segs[3].sweep * 0.2 - 1e-9, "never at the edge (no fake near-miss)")
			end
			local _, bad = Selectors.wheelSegments({ { itemId = "a", rarity = "Common", probability = 0.5 } })
			t.ok(not bad, "tables not summing to 1 are flagged")
		end,
		["owned permanent offers are suppressed; unconfigured are disabled"] = function(t)
			local s = Fixtures.newPlayer(NOW)
			s.owned["skin.candy_swirl"] = true
			t.eq(Selectors.offer(s, "offer.skin.candy_swirl").visible, false, "earned free -> no repurchase")
			local skip = Selectors.offer(s, "offer.consumable.skip_token")
			t.eq(skip.purchasable, false)
			t.eq(skip.reason, "unavailable")
			t.ok(Selectors.offer(s, "offer.wings.ornate").purchasable)
		end,
		["skip token rules"] = function(t)
			t.eq(Selectors.skipToken(Fixtures.newPlayer(NOW)).reason, "none")
			t.ok(Selectors.skipToken(Fixtures.skipToken(NOW)).canUse)
			local last = Fixtures.skipToken(NOW)
			last.isLastAvailableStage = true
			t.eq(Selectors.skipToken(last).reason, "last_stage", "disabled at the last available stage")
		end,
		["daily track never resets on a missed day"] = function(t)
			local s = Fixtures.utcRollover(NOW)
			local d = Selectors.dailyTrack(s, NOW)
			t.eq(d.claims[3].status, "claimed")
			t.eq(d.claims[4].status, "locked")
			t.eq(d.nextIn, 5)
			local p = Selectors.playtime(Fixtures.activeMinutes(NOW, 20))
			t.ok(p.speed and p.attack and not p.needle, "10 and 20 minute bonuses only")
			t.ok(p.t15 and not p.t30, "15-minute ticket only")
		end,
		["stage progress only while in a stage; hearts only in runs"] = function(t)
			t.ok(not Selectors.stageProgress(Fixtures.newPlayer(NOW)).visible)
			local sp = Selectors.stageProgress(Fixtures.stageAt99(NOW))
			t.ok(sp.visible)
			t.eq(sp.done, 99)
			t.ok(Selectors.hearts(Fixtures.stageAt99(NOW)).visible)
			t.ok(Selectors.boss(Fixtures.boss(NOW)).visible)
			t.ok(not Selectors.boss(Fixtures.stageAt99(NOW)).visible)
		end,
	},

	Format = {
		["numbers, durations, percents"] = function(t)
			t.eq(Format.number(1234), "1,234")
			t.eq(Format.number(2500000), "2.5M")
			t.eq(Format.compact(999), "999")
			t.eq(Format.compact(1200), "1.2K")
			t.eq(Format.duration(65), "1:05")
			t.eq(Format.duration(3725), "1:02:05")
			t.eq(Format.percent(0.7), "70%")
			t.eq(Format.percent(0.23), "23%")
			t.eq(Format.percent(0.06), "6%")
			t.eq(Format.percent(0.009), "0.9%")
			t.eq(Format.percent(0.001), "0.1%")
		end,
	},

	Pool = {
		["caps and reuses objects"] = function(t)
			local made = 0
			local p = Pool.new(function()
				made += 1
				return { n = made }
			end, function(o)
				o.reset = true
			end, 2)
			local a, b = p:acquire(), p:acquire()
			t.eq(p:acquire(), nil, "cap reached -> nil, effect skipped")
			p:release(a)
			p:release(a)
			t.eq(p:stats().free, 1, "double release ignored")
			local c = p:acquire()
			t.ok(c == a and c.reset, "reused")
			t.eq(made, 2)
			t.ok(b ~= nil)
		end,
	},
}
