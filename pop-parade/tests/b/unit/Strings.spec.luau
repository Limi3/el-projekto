local Env = require(script.Parent.Env)
local Strings = require(Env.Content.Strings)
local VisualCatalog = require(Env.Content.VisualCatalog)
local AudioCatalog = require(Env.Content.AudioCatalog)

return {
	Strings = {
		["dynamic key families are complete"] = function(t)
			for _, n in { "Needle", "Speed", "Attack", "Sound", "Inventory", "Shop", "More", "Wheel", "Rewards", "Journal", "Settings" } do
				t.ok(Strings.has("menu." .. n), "menu." .. n)
			end
			for _, n in { "Needle", "Speed", "Attack", "Sound", "Inventory", "Shop", "More" } do
				t.ok(Strings.has("tip." .. n), "tip." .. n)
			end
			for _, n in { "Needle", "Speed", "Attack", "Hits", "Life" } do
				t.ok(Strings.has("upgrade." .. n) and Strings.has("upgrade." .. n .. ".desc"), "upgrade." .. n)
			end
			for _, n in { "NeedleSkin", "Trail", "Wings", "PopEffect", "Sound", "Accessory", "Consumable" } do
				t.ok(Strings.has("inv.cat." .. n), "inv.cat." .. n)
			end
			for _, n in { "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
				t.ok(Strings.has("rarity." .. n), "rarity." .. n)
			end
			for _, n in { "speed", "attack", "needle" } do
				t.ok(Strings.has("stat." .. n), "stat." .. n)
			end
			for _, n in { "NOT_READY", "INVALID_REQUEST", "RATE_LIMITED", "INSUFFICIENT_FUNDS", "NOT_OWNED", "LOCKED", "UNAVAILABLE", "ALREADY_CLAIMED", "TIMEOUT" } do
				t.ok(Strings.has("err." .. n), "err." .. n)
			end
		end,
		["every catalog entry has a name"] = function(t)
			for _, d in VisualCatalog.LIST do
				t.ok(Strings.has(d.nameKey), d.nameKey)
			end
			for _, d in AudioCatalog.LIST do
				t.ok(Strings.has(d.nameKey), d.nameKey)
			end
		end,
		["first instruction is exactly the spec sentence"] = function(t)
			t.eq(Strings.t("hint.first"), "Walk toward balloons to pop!")
			t.eq(Strings.t("hud.xp_line", { level = 12, current = 340, needed = 500, remaining = 160 }), "Level 12 · 340 / 500 XP · 160 to next level")
		end,
		["no sound asset IDs are invented"] = function(t)
			for _, d in AudioCatalog.LIST do
				t.eq(d.assetId, nil, d.id .. " has no asset yet")
			end
			t.eq(#AudioCatalog.FREE_POP_SOUNDS, 5)
		end,
	},
}
