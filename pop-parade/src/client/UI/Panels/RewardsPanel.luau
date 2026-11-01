--!strict
-- Rewards: 7-claim daily sign-in track (missed days never reset it), UTC reset countdown,
-- today's active-play bonuses (10/20/30 min) and Spin Tickets (15/30 min), and Double XP with
-- its exact rules. All values come from A's state; claims are server-validated.

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Icons = require(script.Parent.Parent.Icons)
local Panel = require(script.Parent.Parent.Panel)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)

local RewardsPanel = {}
RewardsPanel.__index = RewardsPanel

function RewardsPanel.new(ctx: any)
	local S = ctx.S
	local self = setmetatable({ ctx = ctx, tiles = {} :: { any }, claiming = false }, RewardsPanel)
	self.panel = Panel.new(ctx.layer, { name = "Rewards", title = S.t("rewards.title"), icon = "Rewards", color = Theme.color.coins, closeText = S.t("ui.close"), width = 600, height = 600 })
	local body = self.panel.body

	Panel.section(body, S.t("rewards.daily"), 1)
	local track = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 86), LayoutOrder = 2, Parent = body })
	Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center).Parent = track
	for i = 1, 7 do
		local tile = Kit.new("Frame", { BackgroundColor3 = Theme.color.white, Size = UDim2.fromOffset(70, 84), LayoutOrder = i, Parent = track })
		Kit.corner(12).Parent = tile
		local stroke = Kit.stroke(Theme.color.paperDim, 2)
		stroke.Parent = tile
		local ic = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = tile })
		Icons.draw(if i == 7 then "gift" else "wheel", ic, if i == 7 then Theme.color.primary else Theme.color.tickets)
		local lbl = Kit.label(S.t("rewards.daily_day", { n = i }), { size = 13, font = Theme.font.bold, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 18) })
		lbl.Position = UDim2.fromOffset(0, 42)
		lbl.Parent = tile
		local st = Kit.label("", { size = 12, color = Theme.color.inkSoft, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 18) })
		st.Position = UDim2.fromOffset(0, 60)
		st.Parent = tile
		table.insert(self.tiles, { frame = tile, stroke = stroke, status = st })
	end
	self.claim = Kit.button({ text = S.t("ui.claim"), color = Theme.color.coins, size = UDim2.new(1, 0, 0, 56), order = 3, textSize = 22, onClick = function()
		self:_claim()
	end })
	self.claim.Parent = body
	self.dailyInfo = Kit.label("", { size = 15, color = Theme.color.inkSoft, order = 4, frameSize = UDim2.new(1, 0, 0, 44) })
	self.dailyInfo.Parent = body

	Panel.section(body, S.t("rewards.playtime"), 5)
	self.minutes = Kit.label("", { font = Theme.font.display, size = 20, order = 6 })
	self.minutes.Parent = body
	local track2, fill2 = Kit.bar(Theme.color.good, 16)
	track2.LayoutOrder = 7
	track2.Parent = body
	self.playFill = fill2
	self.milestones = {}
	for i, key in { "rewards.bonus_speed", "rewards.ticket_15", "rewards.bonus_attack", "rewards.bonus_needle", "rewards.ticket_30" } do
		local l = Kit.label("", { size = 16, order = 7 + i })
		l.Parent = body
		self.milestones[key] = l
	end
	Kit.label(S.t("rewards.bonus_note"), { size = 14, color = Theme.color.inkSoft, order = 13 }).Parent = body

	Panel.section(body, S.t("rewards.boost"), 14)
	self.boostInfo = Kit.label("", { size = 16, order = 15 })
	self.boostInfo.Parent = body
	self.boostUse = Kit.button({ text = S.t("rewards.boost_use"), color = Theme.color.xp, size = UDim2.new(1, 0, 0, 52), order = 16, onClick = function()
		local action, payload = ctx.Actions.consumeItem("consumable.double_xp")
		Kit.setEnabled(self.boostUse, false)
		ctx.client:request(action, payload, function(r)
			if not r.ok then
				ctx.toastError(r.code)
			end
			self:refresh(ctx.client.state)
		end)
	end })
	self.boostUse.Parent = body
	Kit.label(S.t("rewards.boost_excludes"), { size = 14, color = Theme.color.inkSoft, order = 17 }).Parent = body
	return self
end

function RewardsPanel._claim(self: any)
	local ctx = self.ctx
	if self.claiming then
		return
	end
	self.claiming = true
	Kit.setEnabled(self.claim, false)
	local action, payload = ctx.Actions.claimDaily()
	ctx.client:request(action, payload, function(r)
		self.claiming = false
		if r.ok then
			ctx.audio:ui("ui.reward")
			ctx.toast(ctx.S.t("ui.claimed"), "good")
		else
			ctx.toastError(r.code)
		end
		self:refresh(ctx.client.state)
	end)
end

function RewardsPanel.tick(self: any, state: any)
	if not self.panel.isOpen or not state then
		return
	end
	local S = self.ctx.S
	local d = Selectors.dailyTrack(state, self.ctx.client:serverNow())
	if d.available and d.nextIn then
		self.dailyInfo.Text = S.t("rewards.daily_next", { time = self.ctx.Format.duration(d.nextIn) }) .. "\n" .. S.t("rewards.daily_note")
	end
	local b = Selectors.boost(state)
	self.boostInfo.Text = if b.visible then S.t("rewards.boost_remaining", { time = self.ctx.Format.duration(b.remaining) }) else S.t("inv.count", { count = (state.consumables and state.consumables["consumable.double_xp"]) or 0 })
end

function RewardsPanel.refresh(self: any, state: any)
	local S = self.ctx.S
	if not state then
		return
	end
	local d = Selectors.dailyTrack(state, self.ctx.client:serverNow())
	for i, t in self.tiles do
		local c = d.claims[i]
		local status = c and c.status or "locked"
		t.status.Text = if status == "claimed" then S.t("ui.claimed") elseif status == "ready" then S.t("ui.claim") else ""
		t.stroke.Color = if status == "ready" then Theme.color.coins elseif status == "claimed" then Theme.color.good else Theme.color.paperDim
		t.frame.BackgroundColor3 = if status == "claimed" then Color3.fromRGB(235, 250, 238) else Theme.color.white
	end
	Kit.setEnabled(self.claim, d.canClaim and not self.claiming)
	Kit.setButtonText(self.claim, if d.canClaim then S.t("ui.claim") else S.t("ui.claimed"))
	local p = Selectors.playtime(state)
	self.minutes.Text = if p.available then S.t("rewards.playtime_minutes", { minutes = math.min(p.minutes, 30) }) else S.t("ui.loading")
	Kit.setBar(self.playFill, math.min(p.minutes, 30) / 30, true)
	local function mark(key: string, done: boolean)
		self.milestones[key].Text = S.t(key) .. (if done then "  ·  " .. S.t("rewards.done") else "")
		self.milestones[key].TextColor3 = if done then Theme.color.good else Theme.color.ink
	end
	mark("rewards.bonus_speed", p.speed)
	mark("rewards.ticket_15", p.t15)
	mark("rewards.bonus_attack", p.attack)
	mark("rewards.bonus_needle", p.needle)
	mark("rewards.ticket_30", p.t30)
	local count = (state.consumables and state.consumables["consumable.double_xp"]) or 0
	local b = state.boost or {}
	local capped = type(b.capSeconds) == "number" and (b.remainingSeconds or 0) + 600 > b.capSeconds
	Kit.setEnabled(self.boostUse, count > 0 and not capped)
	self:tick(state)
end

return RewardsPanel
