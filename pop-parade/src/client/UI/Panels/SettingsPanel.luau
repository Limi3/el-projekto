--!strict
-- Settings: music + SFX volume, reduced motion/effects, screen shake, movement speed (within owned
-- limits). Values are saved through A (SetSetting / SetMoveSpeed); local effects apply instantly.

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Panel = require(script.Parent.Parent.Panel)

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

function SettingsPanel.new(ctx: any)
	local S = ctx.S
	local self = setmetatable({ ctx = ctx }, SettingsPanel)
	self.panel = Panel.new(ctx.layer, { name = "Settings", title = S.t("settings.title"), icon = "Settings", color = Theme.color.inkSoft, closeText = S.t("ui.close"), width = 520, height = 560 })
	local body = self.panel.body
	local function send(key: string, value: any)
		ctx.settings:applyLocal(key, value)
		local action, payload = ctx.Actions.setSetting(key, value)
		ctx.client:request(action, payload, function(r)
			if not r.ok then
				ctx.toastError(r.code)
			end
		end)
	end
	local pct = function(v: number)
		return tostring(math.floor(v * 100 + 0.5)) .. "%"
	end
	local music, setMusic = Kit.slider(S.t("settings.music"), 0, 1, 0.1, 0.5, pct, function(v)
		send("music", v)
	end, 1)
	music.Parent = body
	local sfx, setSfx = Kit.slider(S.t("settings.sfx"), 0, 1, 0.1, 0.8, pct, function(v)
		send("sfx", v)
	end, 2)
	sfx.Parent = body
	local reduced, setReduced = Kit.toggle(S.t("settings.reduced"), false, function(v)
		send("reducedEffects", v)
	end, 3)
	reduced.Parent = body
	local shake, setShake = Kit.toggle(S.t("settings.shake"), true, function(v)
		send("shake", v)
	end, 4)
	shake.Parent = body
	local speed, setSpeed = Kit.slider(S.t("settings.speed"), 12, 16, 1, 16, function(v)
		return tostring(v)
	end, function(v)
		local action, payload = ctx.Actions.setMoveSpeed(v)
		ctx.client:request(action, payload, function(r)
			if not r.ok then
				ctx.toastError(r.code)
			end
		end)
	end, 5)
	speed.Parent = body
	self.setters = { music = setMusic, sfx = setSfx, reduced = setReduced, shake = setShake, speed = setSpeed }
	return self
end

function SettingsPanel.refresh(self: any, state: any)
	if not state or not state.settings then
		return
	end
	local st = state.settings
	if type(st.music) == "number" then
		self.setters.music(st.music)
	end
	if type(st.sfx) == "number" then
		self.setters.sfx(st.sfx)
	end
	self.setters.reduced(st.reducedEffects == true)
	self.setters.shake(st.shake ~= false)
	local range = self.ctx.balance and self.ctx.balance.speedRange(state)
	if range then
		self.setters.speed(state.selectedSpeed or range.max, range.min, range.max)
	end
end

return SettingsPanel
