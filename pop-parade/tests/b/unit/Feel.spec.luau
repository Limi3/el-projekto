local Env = require(script.Parent.Env)
local root = script.Parent.Parent
local DamageMerge = require(Env.Client.Util.DamageMerge)
local Onboarding = require(Env.Client.State.Onboarding)
local MockBalance = require(root.mock.MockBalance)
local Fixtures = require(root.mock.Fixtures)

local NOW = 1793548800

return {
	DamageMerge = {
		["rapid hits merge, slow hits make new numbers, oldest evicted at cap"] = function(t)
			local m = DamageMerge.new(0.3, 2)
			local k1, e1 = m:add(0, 5)
			local k2, e2 = m:add(0.1, 5)
			t.eq(k1, "new")
			t.eq(k2, "merge")
			t.ok(e1 == e2 and e2.total == 10 and e2.hits == 2, "merged total")
			local k3 = m:add(1.0, 7)
			t.eq(k3, "new")
			local _, _, evicted = m:add(2.0, 3)
			t.ok(evicted ~= nil and evicted.total == 10, "cap evicts the oldest number")
			t.eq(#m:expire(10, 0.9), 2, "everything expires")
		end,
	},
	Onboarding = {
		["one objective at a time, starting with the spec sentence key"] = function(t)
			local s = Fixtures.newPlayer(NOW)
			local flags = { pops = 0, upgradesBought = 0, enteredStage = false, bossSeen = false }
			t.eq(Onboarding.next(s, MockBalance, flags), "hint.first")
			flags.pops = 3
			t.eq(Onboarding.next(s, MockBalance, flags), "hint.route", "no coins yet -> route, not a shop nag")
			s.coins = 50
			t.eq(Onboarding.next(s, MockBalance, flags), "hint.upgrade")
			flags.upgradesBought = 1
			t.eq(Onboarding.next(s, MockBalance, flags), "hint.route")
			local st = Fixtures.stageAt99(NOW)
			st.stageProgress.done = 100
			flags.enteredStage = true
			t.eq(Onboarding.next(st, MockBalance, flags), "hint.boss")
		end,
	},
}
