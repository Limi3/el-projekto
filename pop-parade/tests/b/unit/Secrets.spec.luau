local Env = require(script.Parent.Env)
local Rubber = require(Env.Content.Layouts.RubberStage001)
local SecretsLayout = require(Env.World.SecretsLayout)
local Validator = require(Env.World.LayoutValidator)

return {
	Secrets = {
		["three secrets, one per buff type, stable ids"] = function(t)
			local list = SecretsLayout.placements(Rubber.get())
			t.eq(#list, 3)
			local buffs = {}
			for _, s in list do
				buffs[s.buffKey] = true
				t.ok(string.match(s.id, "^secret%.[a-z_]+%.[a-z_]+$") ~= nil, "id format " .. s.id)
				t.ok(s.triggerRadius > 0 and s.triggerRadius <= 8, "sane trigger radius")
			end
			t.ok(buffs["buff.secret.speed_1pct"] and buffs["buff.secret.attack_1pct"] and buffs["buff.secret.needle_1pct"], "one of each buff")
		end,
		["hub secrets reachable with free basic movement"] = function(t)
			local list = SecretsLayout.placements(Rubber.get())
			local surfaces = {}
			for _, p in SecretsLayout.hubSurfaces() do
				table.insert(surfaces, Validator.surfaceOf(p))
			end
			for _, s in list do
				if s.theme == "hub" then
					t.ok(Validator.validateSecretAccess(s.pos, surfaces, 1), s.id .. " reachable from the plaza floor")
				end
			end
		end,
		["under-bridge secret reachable from the stage start"] = function(t)
			local stage = Rubber.get()
			local surfaces = {}
			local startIndex = 1
			for i, p in stage.platforms do
				local s = Validator.surfaceOf(p)
				table.insert(surfaces, s)
				if p.kind == "floor" and p.sectionIndex == 0 then
					startIndex = i
				end
			end
			local pos = SecretsLayout.underBridgeAnchor(stage)
			t.ok(Validator.validateSecretAccess(pos, surfaces, startIndex), "reachable by dropping to the catch floor")
		end,
		["secret positions never appear in shared content"] = function(t)
			-- shared content modules must not mention secret coordinates
			local Hub = require(Env.Content.Layouts.Hub).get()
			for _, m in Hub.markers do
				t.ok(string.find(m.id, "secret", 1, true) == nil, "no secret markers in public hub layout")
			end
		end,
	},
}
