local Env = require(script.Parent.Env)
local Palette = require(Env.Content.Palette)
local Materials = require(Env.Content.Materials)
local Rubber = require(Env.Content.Layouts.RubberStage001)
local Parkour = require(Env.Content.Layouts.Parkour001)
local Hub = require(Env.Content.Layouts.Hub)
local Validator = require(Env.World.LayoutValidator)

local function dist(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

return {
	Palette = {
		["has 1000 in-range colours with controlled brightness"] = function(t)
			local minL, maxL = 1, 0
			local distinct = {}
			for i = 0, Palette.STEPS - 1 do
				local c = Palette.color(i)
				t.ok(c.r >= 0 and c.r <= 1 and c.g >= 0 and c.g <= 1 and c.b >= 0 and c.b <= 1, "colour in range at " .. i)
				local L = Palette.luminance(c)
				minL = math.min(minL, L)
				maxL = math.max(maxL, L)
				distinct[string.format("%.3f,%.3f,%.3f", c.r, c.g, c.b)] = true
			end
			local n = 0
			for _ in distinct do
				n += 1
			end
			t.ok(n >= 900, "at least 900 distinguishable steps, got " .. n)
			t.ok(minL > 0.25, "no step too dark (min luminance " .. minL .. ")")
			t.ok(maxL - minL < 0.4, "brightness spread controlled (" .. (maxL - minL) .. ")")
		end,
		["interpolates smoothly and wraps"] = function(t)
			local a = Palette.color(10)
			local b = Palette.color(11)
			local m = Palette.color(10.5)
			t.near(m.r, (a.r + b.r) / 2, 1e-6, "midpoint r")
			local w = Palette.color(1000 + 10)
			t.near(w.g, a.g, 1e-9, "wraps at 1000")
			t.eq(Palette.wrap(-1), 999, "negative wrap")
		end,
		["stepFor spreads a formation across the spectrum"] = function(t)
			t.eq(Palette.stepFor(1, 100), 0)
			t.eq(Palette.stepFor(51, 100), 500)
			t.eq(Palette.stepFor(100, 100), 990)
			t.eq(Palette.stepFor(1, 100, 1005), 5, "offset wraps")
		end,
		["every material supports every palette step"] = function(t)
			for _, key in Materials.ORDER do
				for step = 0, 999, 37 do
					local tr = Materials.treatment(key, step)
					t.ok(tr.body.r >= 0 and tr.body.r <= 1, key .. " body in range")
					t.ok(tr.robloxMaterial ~= nil, key .. " has material")
				end
			end
			t.eq(Materials.treatment("gold", 0).frame.r, 1.0, "gold keeps its gold frame")
		end,
	},

	RubberStage001 = {
		["passes structural + reachability validation"] = function(t)
			local stage = Rubber.get()
			local report = Validator.validateStage(stage, { [stage.id] = true })
			for _, e in report.errors do
				t.ok(false, e)
			end
			t.ok(report.ok, "validator ok")
			t.eq(report.stats.required, 100, "100 required")
			t.eq(report.stats.reachableSurfaces, report.stats.surfaces, "every surface reachable with base movement")
		end,
		["is deterministic"] = function(t)
			local a = Rubber.get()
			t.ok(a == Rubber.get(), "cached")
			t.eq(a.requiredSlotIds[37], "balloon.rubber.001.037", "required slot ids are numbered in route order")
			t.eq(a.requiredSlotIds[100], "balloon.rubber.001.100")
		end,
		["branches into multiple lanes and separates optional balloons"] = function(t)
			local stage = Rubber.get()
			local lanesPerSection = {}
			local optional = 0
			for _, r in stage.routes do
				if not r.optional then
					lanesPerSection[r.sectionIndex] = (lanesPerSection[r.sectionIndex] or 0) + 1
				end
			end
			for _, b in stage.balloons do
				if not b.required then
					optional += 1
					t.ok(string.find(b.routeId, "bonus", 1, true) ~= nil, "optional balloons live on bonus routes")
				end
			end
			t.eq(lanesPerSection[1], 1, "intro section is a single lane")
			t.ok((lanesPerSection[3] or 0) >= 3, "section 3 has three lanes")
			t.eq(optional, 10, "10 optional bonus balloons")
		end,
		["has 6 ordered checkpoints, hazards linked, boss at the end"] = function(t)
			local stage = Rubber.get()
			t.eq(#stage.checkpoints, 6)
			t.ok(#stage.hazards >= 6, "hazards present")
			t.eq(stage.boss.id, "boss.king_puffer")
			t.eq(stage.boss.checkpointId, "cp.rubber.001.06")
			t.ok(stage.boss.arenaCenter.z < stage.checkpoints[6].placement.pos.z, "arena beyond final checkpoint")
			t.eq(stage.nextStageId, nil, "no fake next stage while Wood is design-only")
		end,
		["sweeper never reaches the side lanes"] = function(t)
			local stage = Rubber.get()
			for _, h in stage.hazards do
				if h.behaviorKey == "sweeper" then
					t.ok(h.params.armLength / 2 <= 9, "sweeper radius stays within centre lane + gap")
				end
			end
		end,
	},

	Parkour001 = {
		["main path reachable with base kit; shortcut needs the extra jump"] = function(t)
			local course = Parkour.get()
			local report = Validator.validateParkour(course)
			for _, e in report.errors do
				t.ok(false, e)
			end
			t.ok(report.ok, "validator ok")
			t.eq(report.stats.checkpoints, 4)
			t.ok(report.stats.shortcutLedges >= 2, "shortcut ledges exist")
			t.eq(report.stats.shortcutLedgesReachableWithoutExtraJump, 0, "shortcut is a real extra-jump choice")
		end,
	},

	Hub = {
		["first balloon is right in front of spawn"] = function(t)
			local hub = Hub.get()
			local first = hub.practice[1]
			local spawn = hub.spawn.pos
			t.ok(first.pos.z < spawn.z, "in front (north) of spawn")
			t.ok(dist(first.pos, spawn) < 9, "within a couple of steps")
		end,
		["has every required station"] = function(t)
			local kinds = {}
			for _, m in Hub.get().markers do
				kinds[m.kind] = (kinds[m.kind] or 0) + 1
			end
			t.eq(kinds["kiosk.upgrades"], 5, "five upgrade kiosks")
			t.ok(kinds["display.cosmetics"] ~= nil, "cosmetics display")
			t.eq(kinds["wheel"], 1)
			t.eq(kinds["rewards"], 1)
			t.eq(kinds["gate.stage"], 1)
			t.eq(kinds["gate.parkour"], 1)
			local tiers = {}
			for _, a in Hub.get().afk do
				tiers[a.tier] = true
			end
			t.ok(tiers.free and tiers.premium, "free + premium AFK")
		end,
		["all IDs across hub, stage and parkour are unique"] = function(t)
			local seen = {}
			local function claim(id)
				t.ok(not seen[id], "duplicate " .. tostring(id))
				seen[id] = true
			end
			for _, b in Hub.get().practice do
				claim(b.id)
			end
			for _, m in Hub.get().markers do
				claim(m.id)
			end
			for _, a in Hub.get().afk do
				claim(a.id)
			end
			for _, b in Rubber.get().balloons do
				claim(b.id)
			end
			for _, b in Parkour.get().sideBalloons do
				claim(b.id)
			end
			for _, c in Parkour.get().checkpoints do
				claim(c.id)
			end
		end,
	},
}
