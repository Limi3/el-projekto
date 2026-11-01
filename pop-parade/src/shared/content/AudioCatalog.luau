--!strict
-- Audio descriptors keyed by stable ID.
-- NO real sound IDs are filled in: none have been supplied by the owner yet, and inventing
-- Roblox asset IDs or copying copyrighted sounds is not allowed. Every entry falls back to a
-- silent, visual-only cue until `assetId` is set to an owned/licensed asset.
-- Track supply status in docs/b/ASSET_MANIFEST.md.

export type SoundDescriptor = {
	id: string,
	kind: "pop" | "ui" | "world" | "music",
	nameKey: string,
	assetId: string?, -- "rbxassetid://<n>" once the owner uploads/licenses it; nil = missing
	volume: number,
	pitch: number,
	pitchJitter: number, -- random +/- per play, keeps rapid pops from sounding robotic
	priority: number, -- higher wins when the voice cap is reached
	visualFallback: string, -- what the player sees instead when the asset is missing
	premiumPack: string?, -- optional paid sound-pack key (descriptor only; A owns the product)
}

local LIST: { SoundDescriptor } = {
	-- Five free pop sounds (spec 6)
	{ id = "sound.classic_pop", kind = "pop", nameKey = "item.sound.classic_pop", assetId = nil, volume = 0.6, pitch = 1, pitchJitter = 0.08, priority = 5, visualFallback = "ring" },
	{ id = "sound.soft_bubble", kind = "pop", nameKey = "item.sound.soft_bubble", assetId = nil, volume = 0.5, pitch = 1.1, pitchJitter = 0.06, priority = 5, visualFallback = "bubbles" },
	{ id = "sound.rubber_snap", kind = "pop", nameKey = "item.sound.rubber_snap", assetId = nil, volume = 0.6, pitch = 0.95, pitchJitter = 0.07, priority = 5, visualFallback = "snap" },
	{ id = "sound.squeak", kind = "pop", nameKey = "item.sound.squeak", assetId = nil, volume = 0.5, pitch = 1.2, pitchJitter = 0.1, priority = 5, visualFallback = "squiggle" },
	{ id = "sound.tiny_firework", kind = "pop", nameKey = "item.sound.tiny_firework", assetId = nil, volume = 0.55, pitch = 1, pitchJitter = 0.05, priority = 5, visualFallback = "sparkle" },

	-- Optional paid sound pack descriptors (presentation only)
	{ id = "sound.arcade_blip", kind = "pop", nameKey = "item.sound.arcade_blip", assetId = nil, volume = 0.5, pitch = 1, pitchJitter = 0.05, priority = 5, visualFallback = "pixels", premiumPack = "soundpack.arcade" },
	{ id = "sound.kazoo_toot", kind = "pop", nameKey = "item.sound.kazoo_toot", assetId = nil, volume = 0.5, pitch = 1, pitchJitter = 0.08, priority = 5, visualFallback = "notes", premiumPack = "soundpack.party" },
	{ id = "sound.drum_hit", kind = "pop", nameKey = "item.sound.drum_hit", assetId = nil, volume = 0.6, pitch = 1, pitchJitter = 0.04, priority = 5, visualFallback = "ring", premiumPack = "soundpack.party" },

	-- World / UI
	{ id = "sfx.inflate", kind = "world", nameKey = "sfx.inflate", assetId = nil, volume = 0.35, pitch = 1, pitchJitter = 0.05, priority = 2, visualFallback = "none" },
	{ id = "sfx.boss_windup", kind = "world", nameKey = "sfx.boss_windup", assetId = nil, volume = 0.8, pitch = 1, pitchJitter = 0, priority = 9, visualFallback = "ground_warning" },
	{ id = "sfx.boss_pulse", kind = "world", nameKey = "sfx.boss_pulse", assetId = nil, volume = 0.8, pitch = 1, pitchJitter = 0, priority = 9, visualFallback = "ring" },
	{ id = "sfx.boss_defeat", kind = "world", nameKey = "sfx.boss_defeat", assetId = nil, volume = 0.9, pitch = 1, pitchJitter = 0, priority = 10, visualFallback = "fireworks" },
	{ id = "sfx.checkpoint", kind = "world", nameKey = "sfx.checkpoint", assetId = nil, volume = 0.5, pitch = 1, pitchJitter = 0, priority = 7, visualFallback = "flag" },
	{ id = "sfx.secret_found", kind = "world", nameKey = "sfx.secret_found", assetId = nil, volume = 0.8, pitch = 1, pitchJitter = 0, priority = 10, visualFallback = "sparkle" },
	{ id = "sfx.hurt", kind = "world", nameKey = "sfx.hurt", assetId = nil, volume = 0.6, pitch = 1, pitchJitter = 0.05, priority = 8, visualFallback = "flash" },
	{ id = "ui.click", kind = "ui", nameKey = "sfx.ui_click", assetId = nil, volume = 0.4, pitch = 1, pitchJitter = 0, priority = 6, visualFallback = "none" },
	{ id = "ui.reward", kind = "ui", nameKey = "sfx.ui_reward", assetId = nil, volume = 0.6, pitch = 1, pitchJitter = 0, priority = 8, visualFallback = "none" },
	{ id = "ui.wheel_tick", kind = "ui", nameKey = "sfx.wheel_tick", assetId = nil, volume = 0.3, pitch = 1, pitchJitter = 0.02, priority = 4, visualFallback = "none" },
	{ id = "music.hub", kind = "music", nameKey = "music.hub", assetId = nil, volume = 0.3, pitch = 1, pitchJitter = 0, priority = 1, visualFallback = "none" },
}

local BY_ID: { [string]: SoundDescriptor } = {}
for _, d in LIST do
	assert(BY_ID[d.id] == nil, "duplicate audio id " .. d.id)
	BY_ID[d.id] = d
end

local FREE_POP_SOUNDS = { "sound.classic_pop", "sound.soft_bubble", "sound.rubber_snap", "sound.squeak", "sound.tiny_firework" }

return {
	LIST = LIST,
	BY_ID = BY_ID,
	FREE_POP_SOUNDS = FREE_POP_SOUNDS,
	DEFAULT_POP = "sound.classic_pop",
	get = function(id: string): SoundDescriptor?
		return BY_ID[id]
	end,
	isMissing = function(id: string): boolean
		local d = BY_ID[id]
		return d == nil or d.assetId == nil
	end,
}
