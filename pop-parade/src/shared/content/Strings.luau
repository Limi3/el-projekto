--!strict
-- Localization-ready string table. All player-facing text goes through Strings.t(key, args).
-- Placeholders use {name}. Add languages by adding another table with the same keys;
-- missing keys fall back to English, then to the key itself (visible, so gaps are caught in testing).

local en: { [string]: string } = {
	-- Onboarding / hub
	["hint.first"] = "Walk toward balloons to pop!",
	["hint.upgrade"] = "You have enough Coins for an upgrade. Press Needle!",
	["hint.route"] = "The Rubber route starts through the big arch.",
	["hint.boss"] = "King Puffer awaits at the end of the route!",
	["hub.sign.wood_wip"] = "WOOD WORKSHOP\nUnder construction",
	["hub.sign.stage"] = "RUBBER ROUTE",
	["hub.sign.parkour"] = "RIBBON RUN\nParkour",
	["hub.sign.afk"] = "AFK GARDEN",
	["hub.sign.afk_premium"] = "PREMIUM AFK",
	["hub.sign.upgrades"] = "UPGRADES",
	["hub.sign.wheel"] = "FREE WHEEL",
	["hub.sign.rewards"] = "REWARDS",
	["hub.sign.styles"] = "STYLES",

	-- Menu buttons (one word each)
	["menu.Needle"] = "Needle",
	["menu.Speed"] = "Speed",
	["menu.Attack"] = "Attack",
	["menu.Sound"] = "Sound",
	["menu.Inventory"] = "Inventory",
	["menu.Shop"] = "Shop",
	["menu.More"] = "More",
	["menu.Wheel"] = "Wheel",
	["menu.Rewards"] = "Rewards",
	["menu.Journal"] = "Journal",
	["menu.Settings"] = "Settings",
	["tip.Needle"] = "Upgrade needle damage, extra hits and hearts",
	["tip.Speed"] = "Upgrade and choose your movement speed",
	["tip.Attack"] = "Upgrade how fast your needle attacks",
	["tip.Sound"] = "Pick your pop sound",
	["tip.Inventory"] = "Your styles, accessories and items",
	["tip.Shop"] = "Today's featured items",
	["tip.More"] = "Wheel, rewards, journal and settings",

	-- HUD
	["hud.level"] = "Level {level}",
	["hud.xp"] = "{current} / {needed} XP",
	["hud.xp_to_next"] = "{remaining} to next level",
	["hud.xp_line"] = "Level {level} · {current} / {needed} XP · {remaining} to next level",
	["hud.xp_max"] = "Level {level} · MAX",
	["hud.coins"] = "{coins}",
	["hud.stage_progress"] = "{done} / {total}",
	["hud.stage_label"] = "Stage",
	["hud.boss_hp"] = "{name}  {hp} / {max}",
	["hud.boss_knot"] = "The knot is exposed! Attack now!",
	["hud.hearts"] = "Hearts",
	["hud.boost"] = "2× XP  {time}",
	["hud.boost_paused"] = "(paused)",
	["hud.daily_reset"] = "Daily reset in {time}",
	["hud.connecting"] = "Connecting to server…",
	["hud.unavailable"] = "Server unavailable. Retrying… Your progress is safe on the server.",
	["hud.resyncing"] = "Syncing…",
	["hud.preview_banner"] = "TEST PREVIEW · mock data · nothing here is saved or real",
	["hud.stage_skipped"] = "Skipped",

	-- Generic UI
	["ui.close"] = "Close",
	["ui.back"] = "Back",
	["ui.confirm"] = "Confirm",
	["ui.cancel"] = "Cancel",
	["ui.loading"] = "Loading…",
	["ui.retry"] = "Retry",
	["ui.equip"] = "Equip",
	["ui.equipped"] = "Equipped",
	["ui.owned"] = "Owned",
	["ui.locked"] = "Locked",
	["ui.preview"] = "Preview",
	["ui.claim"] = "Claim",
	["ui.claimed"] = "Claimed",
	["ui.use"] = "Use",
	["ui.buy"] = "Buy",
	["ui.unavailable"] = "Unavailable",
	["ui.price_loading"] = "Price…",
	["ui.price_robux"] = "R$ {price}",
	["ui.price_unknown"] = "Price unavailable",
	["ui.waiting_server"] = "Waiting for the server to confirm…",
	["ui.purchase_pending"] = "Purchase sent. Your item appears once the server confirms it.",
	["ui.free"] = "Free",

	-- Errors (A's stable codes)
	["err.NOT_READY"] = "The server is still getting ready. Try again in a moment.",
	["err.INVALID_REQUEST"] = "That request wasn't valid.",
	["err.RATE_LIMITED"] = "Slow down a little and try again.",
	["err.INSUFFICIENT_FUNDS"] = "Not enough Coins yet.",
	["err.NOT_OWNED"] = "You don't own that yet.",
	["err.LOCKED"] = "That's still locked.",
	["err.UNAVAILABLE"] = "That's not available right now.",
	["err.ALREADY_CLAIMED"] = "Already claimed.",
	["err.TIMEOUT"] = "The server didn't answer. Nothing was spent; please try again.",
	["err.UNKNOWN"] = "Something went wrong. Please try again.",

	-- Upgrades
	["upgrade.title"] = "Upgrades",
	["upgrade.Needle"] = "Needle",
	["upgrade.Speed"] = "Speed",
	["upgrade.Attack"] = "Attack",
	["upgrade.Hits"] = "Hits",
	["upgrade.Life"] = "Life",
	["upgrade.Needle.desc"] = "More damage per attack",
	["upgrade.Speed.desc"] = "Higher top movement speed",
	["upgrade.Attack.desc"] = "Faster attack rate",
	["upgrade.Hits.desc"] = "Hit more balloons per attack (up to 3, never extra boss hits)",
	["upgrade.Life.desc"] = "More maximum hearts (up to 5)",
	["upgrade.level"] = "Level {level}",
	["upgrade.current"] = "Now: {value}",
	["upgrade.next"] = "Next: {value}",
	["upgrade.cost"] = "{cost} Coins",
	["upgrade.max"] = "MAX",
	["upgrade.buy"] = "Upgrade",
	["upgrade.select_speed"] = "Your speed: {speed} (max {max})",

	-- Inventory
	["inv.title"] = "Inventory",
	["inv.cat.NeedleSkin"] = "Needles",
	["inv.cat.Trail"] = "Trails",
	["inv.cat.Wings"] = "Wings",
	["inv.cat.PopEffect"] = "Pop Effects",
	["inv.cat.Sound"] = "Sounds",
	["inv.cat.Accessory"] = "Accessories",
	["inv.cat.Consumable"] = "Items",
	["inv.empty"] = "Nothing here yet. Keep popping!",
	["inv.bonus"] = "Bonus: {text}",
	["inv.cosmetic_only"] = "Cosmetic only, no stat change",
	["inv.count"] = "×{count}",

	-- Sound panel
	["sound.title"] = "Pop Sound",
	["sound.missing"] = "Sound file not added yet. You'll see a visual cue instead.",
	["sound.pack"] = "Sound pack",

	-- Shop
	["shop.title"] = "Shop",
	["shop.featured"] = "Today's Featured",
	["shop.refresh_in"] = "New items in {time}",
	["shop.collection"] = "Collection",
	["shop.direct"] = "Guaranteed: you get exactly this item",
	["shop.no_products"] = "No items are on sale right now.",

	-- Wheel
	["wheel.title"] = "Free Wheel",
	["wheel.tickets"] = "Spin Tickets: {count}",
	["wheel.spin"] = "Spin",
	["wheel.no_tickets"] = "No Spin Tickets. Get more from daily rewards and active play.",
	["wheel.odds"] = "Exact odds for each prize",
	["wheel.free_only"] = "Spins are always free. Tickets can't be bought.",
	["wheel.result"] = "You won {name}!",
	["wheel.duplicate"] = "Duplicate {name}: converted to {coins} Coins",
	["wheel.recovered"] = "Recovered your last spin result.",
	["wheel.founder_progress"] = "Founder skin: {done} / {total} free spins",
	["wheel.spinning"] = "Spinning…",
	["wheel.dup_short"] = "duplicate = {coins} Coins",

	-- Rewards
	["rewards.title"] = "Rewards",
	["rewards.daily"] = "Daily Sign-in",
	["rewards.daily_day"] = "Claim {n}",
	["rewards.daily_next"] = "Next claim in {time}",
	["rewards.daily_note"] = "Missing a day never resets your track.",
	["rewards.playtime"] = "Today's Active Play",
	["rewards.playtime_minutes"] = "{minutes} / 30 min",
	["rewards.bonus_speed"] = "10 min: +1% speed",
	["rewards.bonus_attack"] = "20 min: +1% attack speed",
	["rewards.bonus_needle"] = "30 min: +1% needle damage",
	["rewards.done"] = "Done!",
	["rewards.bonus_note"] = "Lasts until the daily reset. AFK stations don't count.",
	["rewards.ticket_15"] = "15 min: Spin Ticket",
	["rewards.ticket_30"] = "30 min: Spin Ticket",
	["rewards.boost"] = "Double XP",
	["rewards.boost_remaining"] = "{time} left (paused while offline, idle or AFK)",
	["rewards.boost_use"] = "Use Double XP (+10 min)",
	["rewards.boost_excludes"] = "Excludes daily rewards, secrets, tickets and first-clear XP.",

	-- Skip token
	["skip.title"] = "Use a Skip Token?",
	["skip.body"] = "Skip {stage}: the 100 balloons and its boss. The next stage opens.",
	["skip.not_awarded"] = "You will NOT get: this stage's Coins, XP, boss trophy, free wings, secrets or clear records.",
	["skip.revisit"] = "You can come back and clear it properly later.",
	["skip.last_stage"] = "This is the last stage available, so a token can't be used here. Your tokens are kept.",
	["skip.have"] = "You have {count} Skip Token(s)",

	-- Journal / secrets
	["journal.title"] = "Secret Journal",
	["journal.found"] = "Found",
	["journal.progress"] = "{found} / {total} golden secrets found",
	["journal.unknown_hint"] = "Somewhere in the world, something golden is hiding. Look for small clues.",
	["secret.rubber.waterfall.desc"] = "You found the cave behind the fizzy falls. Permanent +1% speed.",
	["secret.hub.big_top.desc"] = "You climbed to the very top of the Big Top. Permanent +1% attack speed.",
	["secret.rubber.underbridge.desc"] = "You found the nook under the rainbow bridge. Permanent +1% needle damage.",
	["journal.unknown"] = "???",
	["journal.buffs"] = "Permanent bonuses: +{speed}% speed, +{attack}% attack, +{needle}% needle",
	["secret.found_title"] = "Golden Secret Found!",
	["secret.found_body"] = "{name}: permanent +1% {stat} on your whole account.",
	["secret.rubber.waterfall"] = "Behind the Fizzy Falls",
	["secret.hub.big_top"] = "Big Top Peek",
	["secret.rubber.underbridge"] = "Under the Rainbow Bridge",
	["stat.speed"] = "speed",
	["stat.attack"] = "attack speed",
	["stat.needle"] = "needle damage",

	-- Settings
	["settings.title"] = "Settings",
	["settings.music"] = "Music",
	["settings.sfx"] = "Sound effects",
	["settings.reduced"] = "Reduced motion & effects",
	["settings.shake"] = "Screen shake",
	["settings.speed"] = "Movement speed",
	["settings.graphics"] = "Graphics",
	["settings.dof"] = "Depth of field",
	["settings.bloom"] = "Glow (bloom)",
	["settings.sunRays"] = "Sun rays",
	["settings.shadows"] = "Shadows",
	["settings.graphics_note"] = "Turn these off if the game feels slow. Reduced motion also turns off depth of field and sun rays.",
	["settings.on"] = "On",
	["settings.off"] = "Off",

	-- AFK
	["afk.free"] = "Free AFK station",
	["afk.premium"] = "Premium AFK station",
	["afk.label_free"] = "AFK rate: about 35% of active play",
	["afk.label_premium"] = "AFK rate: 1.5× the free station",
	["afk.note"] = "Station damage is shown against this station's own balloon. It doesn't count as active play.",

	-- Boss / stage
	["boss.king_puffer"] = "King Puffer",
	["boss.defeated"] = "King Puffer popped!",
	["stage.rubber.001"] = "Rubber Route",
	["parkour.001"] = "Ribbon Run",
	["checkpoint.reached"] = "Checkpoint!",
	["stage.return_sign"] = "Missed one? Hop back up!",
	["stage.section.1"] = "1 · WARM-UP WAY",
	["stage.section.2"] = "2 · THE SPLIT",
	["stage.section.3"] = "3 · SWEEPER STREET",
	["stage.section.4"] = "4 · HOP HOP HILL",
	["stage.section.5"] = "5 · PUFF ALLEY",
	["stage.section.boss"] = "KING PUFFER'S DRUM",
	["boss.intro_title"] = "KING PUFFER",
	["boss.intro_sub"] = "Dodge the air rings. Pop the glowing knot!",
	["boss.victory_title"] = "VICTORY!",
	["boss.victory_sub"] = "King Puffer is popped. The server will confirm your rewards.",
	["run.defeat_title"] = "POPPED!",
	["run.defeat_sub"] = "Back to your last checkpoint. Your Coins and progress are safe.",
	["parkour.finish_title"] = "FINISH!",
	["parkour.finish_sub"] = "Ribbon Run complete. Rewards arrive once the server confirms.",
	["parkour.normalized"] = "Challenge mode: everyone has the same stats and one extra jump.",

	-- Materials / themes
	["material.rubber"] = "Rubber",
	["material.wood"] = "Wood",
	["material.steel"] = "Steel",
	["material.gold"] = "Gold",
	["material.diamond"] = "Diamond",
	["theme.hub"] = "Pop Plaza",
	["theme.rubber"] = "Rubber",
	["theme.wood"] = "Wood",
	["theme.candy"] = "Candy",
	["theme.steel"] = "Steel",
	["theme.chocolate"] = "Chocolate",
	["theme.gold"] = "Gold",
	["theme.ice_cream"] = "Ice Cream",
	["theme.diamond"] = "Diamond",
	["theme.halloween"] = "Halloween",

	-- Items
	["item.unknown"] = "Mystery Item",
	["item.skin.default"] = "Classic Needle",
	["item.skin.rubber_twist"] = "Rubber Twist",
	["item.skin.candy_swirl"] = "Candy Swirl",
	["item.skin.chrome_spiral"] = "Chrome Spiral",
	["item.skin.neon_helix"] = "Neon Helix",
	["item.skin.prism_crown"] = "Prism Crown",
	["item.skin.wheel_founder"] = "Founder's Ticket Punch",
	["item.skin.wheel_founder.desc"] = "Wheel-exclusive: earned after 25 free spins. Never sold.",
	["item.trail.rainbow"] = "Rainbow Trail",
	["item.trail.rainbow_deluxe"] = "Rainbow Trail Deluxe",
	["item.trail.rocket"] = "Rocket Trail",
	["item.trail.rocket_deluxe"] = "Rocket Trail Deluxe",
	["item.trail.neon"] = "Neon Trail",
	["item.trail.neon_deluxe"] = "Neon Trail Deluxe",
	["item.wings.basic"] = "Paper Wings",
	["item.wings.ornate"] = "Ornate Wings",
	["item.wings.desc"] = "One extra jump in the air. Same jump for every wing style.",
	["item.popfx.confetti"] = "Confetti",
	["item.popfx.streamers"] = "Streamers",
	["item.popfx.starburst_deluxe"] = "Starburst Deluxe",
	["item.accessory.zoom_sneakers"] = "Zoom Sneakers",
	["item.accessory.focus_goggles"] = "Focus Goggles",
	["item.accessory.sharp_glove"] = "Sharp Glove",
	["item.consumable.skip_token"] = "Skip Token",
	["item.consumable.skip_token.desc"] = "Skips one unfinished stage without its rewards.",
	["item.consumable.double_xp"] = "Double XP",
	["item.consumable.double_xp.desc"] = "2× active-play XP for 10 minutes.",
	["item.sound.classic_pop"] = "Classic Pop",
	["item.sound.soft_bubble"] = "Soft Bubble",
	["item.sound.rubber_snap"] = "Rubber Snap",
	["item.sound.squeak"] = "Squeak",
	["item.sound.tiny_firework"] = "Tiny Firework",
	["item.sound.arcade_blip"] = "Arcade Blip",
	["item.sound.kazoo_toot"] = "Kazoo Toot",
	["item.sound.drum_hit"] = "Drum Hit",

	-- Sound effect names (asset manifest / settings)
	["sfx.inflate"] = "Balloon inflate",
	["sfx.boss_windup"] = "Boss wind-up",
	["sfx.boss_pulse"] = "Boss air pulse",
	["sfx.boss_defeat"] = "Boss defeated",
	["sfx.checkpoint"] = "Checkpoint",
	["sfx.secret_found"] = "Secret found",
	["sfx.hurt"] = "Ouch",
	["sfx.ui_click"] = "Button click",
	["sfx.ui_reward"] = "Reward",
	["sfx.wheel_tick"] = "Wheel tick",
	["music.hub"] = "Plaza music",

	-- Acquisition labels
	["acq.wheel_exclusive"] = "Wheel exclusive",
	["acq.wheel_or_direct"] = "From the free wheel, or buy directly",
	["acq.first_boss"] = "Earned by defeating your first boss",
	["acq.earned"] = "Earned in play",
	["acq.purchase"] = "Robux item",

	-- Rarities (display only)
	["rarity.Common"] = "Common",
	["rarity.Uncommon"] = "Uncommon",
	["rarity.Rare"] = "Rare",
	["rarity.Epic"] = "Epic",
	["rarity.Legendary"] = "Legendary",
}

local LANGS: { [string]: { [string]: string } } = { en = en }

local Strings = {}
Strings.lang = "en"
Strings.en = en

function Strings.has(key: string): boolean
	return en[key] ~= nil
end

function Strings.t(key: string, args: { [string]: any }?): string
	local tbl = LANGS[Strings.lang] or en
	local s = tbl[key] or en[key] or key
	if args then
		s = (string.gsub(s, "{(%w+)}", function(name)
			local val = args[name]
			if val == nil then
				return "{" .. name .. "}"
			end
			return tostring(val)
		end))
	end
	return s
end

return Strings
