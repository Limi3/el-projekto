--!strict
-- Free wheel (Spin Tickets only; tickets can't be bought).
--   * exact per-item odds from A are listed BEFORE spinning; slices are drawn exactly to size
--   * the result is resolved and stored by the server first; the animation only plays it back
--   * one request in flight; a lost reply is retried with the SAME request id (no reroll)
--   * after reconnect, an unseen stored result is shown as "recovered", not spun again
--   * the pointer stops inside the middle of the won slice: no fake near-misses

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Panel = require(script.Parent.Parent.Panel)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)

local WheelPanel = {}
WheelPanel.__index = WheelPanel

local RADIUS = 130

function WheelPanel.new(ctx: any)
	local S = ctx.S
	local self = setmetatable({
		ctx = ctx,
		pendingId = nil :: string?,
		spinning = false,
		shownSpinId = nil :: string?,
		drawnFor = nil :: any,
		rotation = 0,
	}, WheelPanel)
	self.panel = Panel.new(ctx.layer, { name = "Wheel", title = S.t("wheel.title"), icon = "Wheel", color = Theme.color.tickets, closeText = S.t("ui.close"), width = 620, height = 600 })
	local body = self.panel.body

	local top = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, RADIUS * 2 + 30), LayoutOrder = 1, Parent = body })
	local wheelHolder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(RADIUS * 2, RADIUS * 2), Position = UDim2.fromOffset(0, 20), Parent = top })
	self.wheel = Kit.new("Frame", { Name = "Wheel", BackgroundColor3 = Theme.color.white, Size = UDim2.fromScale(1, 1), Parent = wheelHolder })
	Kit.corner(999).Parent = self.wheel
	local hub = Kit.new("Frame", { BackgroundColor3 = Theme.color.golden, Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3, Parent = wheelHolder })
	Kit.corner(999).Parent = hub
	Kit.stroke(Theme.color.white, 3).Parent = hub
	local pointer = Kit.new("Frame", { BackgroundColor3 = Theme.color.ink, Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -6), Rotation = 45, ZIndex = 4, Parent = wheelHolder })
	Kit.stroke(Theme.color.white, 2).Parent = pointer

	local side = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(RADIUS * 2 + 20, 10), Size = UDim2.new(1, -(RADIUS * 2 + 20), 1, -10), Parent = top })
	Kit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Left).Parent = side
	self.tickets = Kit.label("", { font = Theme.font.display, size = 22, order = 1 })
	self.tickets.Parent = side
	self.founder = Kit.label("", { size = 15, color = Theme.color.inkSoft, order = 2 })
	self.founder.Parent = side
	self.spin = Kit.button({ text = S.t("wheel.spin"), color = Theme.color.tickets, size = UDim2.new(1, 0, 0, 60), order = 3, textSize = 24, onClick = function()
		self:_spin()
	end })
	self.spin.Parent = side
	self.result = Kit.label("", { font = Theme.font.display, size = 18, order = 4, frameSize = UDim2.new(1, 0, 0, 52) })
	self.result.Parent = side
	Kit.label(S.t("wheel.free_only"), { size = 14, color = Theme.color.inkSoft, order = 5, frameSize = UDim2.new(1, 0, 0, 40) }).Parent = side

	Kit.label(S.t("wheel.odds"), { font = Theme.font.display, size = 20, order = 2 }).Parent = body
	self.odds = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = body })
	Kit.list(Enum.FillDirection.Vertical, 4).Parent = self.odds

	ctx.client.LateResult:Connect(function(requestId: string, r: any)
		if requestId == self.pendingId then
			self:_onResult(r, true)
		end
	end)
	return self
end

function WheelPanel._draw(self: any, segs: { any })
	self.wheel:ClearAllChildren()
	Kit.corner(999).Parent = self.wheel
	local rimArc = (2 * math.pi * RADIUS) / 360
	for _, seg in segs do
		local color = Theme.rarity[seg.rarity] or Theme.color.disabled
		local a = seg.start
		local stop = seg.start + seg.sweep
		while a < stop - 1e-9 do
			local w = math.min(1, stop - a) -- final partial degree keeps exact proportion
			Kit.new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = color,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, math.max(0.5, rimArc * w * 1.6), 0.5, 0),
				Rotation = a + w / 2,
				Parent = self.wheel,
			})
			a += w
		end
		-- thin white divider at each slice edge
		Kit.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Theme.color.white, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1.5, 0.5, 0), Rotation = seg.start, ZIndex = 2, Parent = self.wheel })
	end
end

function WheelPanel._renderOdds(self: any, state: any, segs: { any }, valid: boolean)
	local ctx = self.ctx
	local S = ctx.S
	self.odds:ClearAllChildren()
	Kit.list(Enum.FillDirection.Vertical, 4).Parent = self.odds
	for i, seg in segs do
		local row = Kit.new("Frame", { BackgroundColor3 = Theme.color.white, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = i, Parent = self.odds })
		Kit.corner(10).Parent = row
		local chip = Kit.new("Frame", { BackgroundColor3 = Theme.rarity[seg.rarity] or Theme.color.disabled, Size = UDim2.fromOffset(16, 24), Position = UDim2.fromOffset(10, 8), Parent = row })
		Kit.corner(6).Parent = chip
		local d = ctx.Content.VisualCatalog.get(seg.itemId)
		local dup = state.wheel and state.wheel.duplicateCoins and state.wheel.duplicateCoins[seg.rarity]
		local name = S.t(d.nameKey) .. "  ·  " .. S.t("rarity." .. seg.rarity) .. (if dup then "  ·  " .. S.t("wheel.dup_short", { coins = ctx.Format.number(dup) }) else "")
		local l = Kit.label(name, { size = 15, frameSize = UDim2.new(1, -120, 1, 0) })
		l.Position = UDim2.fromOffset(36, 0)
		l.Parent = row
		local p = Kit.label(ctx.Format.percent(seg.probability), { font = Theme.font.display, size = 18, align = Enum.TextXAlignment.Right, frameSize = UDim2.new(0, 90, 1, 0) })
		p.AnchorPoint = Vector2.new(1, 0)
		p.Position = UDim2.new(1, -12, 0, 0)
		p.Parent = row
	end
	if not valid then
		Kit.label(S.t("ui.unavailable"), { color = Theme.color.bad, order = 99 }).Parent = self.odds
	end
end

function WheelPanel.refresh(self: any, state: any)
	local ctx = self.ctx
	local S = ctx.S
	if not state then
		return
	end
	local segs, valid = Selectors.wheelSegments(state.wheel and state.wheel.table)
	self.segs = segs
	self.valid = valid
	if self.drawnFor ~= (state.wheel and state.wheel.table) then
		self.drawnFor = state.wheel and state.wheel.table
		self:_draw(segs)
		self:_renderOdds(state, segs, valid)
	end
	local tickets = state.spinTickets or 0
	self.tickets.Text = S.t("wheel.tickets", { count = tickets })
	self.founder.Text = if state.owned and state.owned["skin.wheel_founder"] then S.t("item.skin.wheel_founder") .. " · " .. S.t("ui.owned") else S.t("wheel.founder_progress", { done = math.min(state.spinsCompleted or 0, state.founderSpinsRequired or 25), total = state.founderSpinsRequired or 25 })
	local canSpin = valid and tickets > 0 and not self.spinning and self.pendingId == nil
	Kit.setEnabled(self.spin, canSpin or (self.pendingId ~= nil and not self.spinning))
	if self.pendingId and not self.spinning then
		Kit.setButtonText(self.spin, S.t("ui.retry"))
	elseif tickets <= 0 then
		Kit.setButtonText(self.spin, S.t("wheel.spin"))
		if not self.spinning and self.result.Text == "" then
			self.result.Text = S.t("wheel.no_tickets")
		end
	else
		Kit.setButtonText(self.spin, if self.spinning then S.t("wheel.spinning") else S.t("wheel.spin"))
	end
	-- recover a stored result we never displayed (e.g. reply lost, then rejoined)
	local pending = state.pendingSpin
	if pending and pending.spinId ~= self.shownSpinId and not self.spinning and self.pendingId == nil and self.shownSpinId ~= nil then
		self.shownSpinId = pending.spinId
		self:_showOutcome(pending, true)
	elseif pending and self.shownSpinId == nil then
		self.shownSpinId = pending.spinId -- first sight on join: treat as already seen
	end
end

function WheelPanel._spin(self: any)
	local ctx = self.ctx
	if self.spinning then
		return
	end
	self.spinning = true
	self.result.Text = ""
	Kit.setEnabled(self.spin, false)
	Kit.setButtonText(self.spin, ctx.S.t("wheel.spinning"))
	local action, payload = ctx.Actions.requestSpin()
	-- retry reuses the same id so the server returns the SAME stored outcome
	self.pendingId = ctx.client:request(action, payload, function(r)
		self:_onResult(r, false)
	end, self.pendingId)
end

function WheelPanel._onResult(self: any, r: any, recovered: boolean)
	local ctx = self.ctx
	if not r.ok then
		self.spinning = false
		if r.code == "TIMEOUT" then
			self.result.Text = ctx.S.t("ui.waiting_server")
		else
			self.pendingId = nil
			ctx.toastError(r.code)
		end
		self:refresh(ctx.client.state)
		return
	end
	self.pendingId = nil
	local outcome = r.data
	self.shownSpinId = outcome.spinId
	self:_animateTo(outcome.itemId, function()
		self.spinning = false
		self:_showOutcome(outcome, recovered)
		self:refresh(ctx.client.state)
	end)
end

function WheelPanel._animateTo(self: any, itemId: string, done: () -> ())
	local angle = Selectors.wheelLandingAngle(self.segs or {}, itemId, math.random())
	if not angle then
		done()
		return
	end
	local start = self.rotation % 360
	local target = -angle
	while target > start - 360 * 4 do
		target -= 360
	end
	self.wheel.Rotation = start
	self.rotation = target
	local tw = Kit.tween(self.wheel, TweenInfo.new(3.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target })
	if tw then
		tw.Completed:Once(done)
	else
		self.wheel.Rotation = target
		done()
	end
end

function WheelPanel._showOutcome(self: any, outcome: any, recovered: boolean)
	local ctx = self.ctx
	local S = ctx.S
	local name = S.t(ctx.Content.VisualCatalog.get(outcome.itemId).nameKey)
	local text = if outcome.duplicate then S.t("wheel.duplicate", { name = name, coins = ctx.Format.number(outcome.coins or 0) }) else S.t("wheel.result", { name = name })
	if outcome.founderGranted then
		text ..= "\n" .. S.t("item.skin.wheel_founder") .. "!"
	end
	if recovered then
		text = S.t("wheel.recovered") .. "\n" .. text
	end
	self.result.Text = text
	ctx.audio:ui("ui.reward")
end

return WheelPanel
