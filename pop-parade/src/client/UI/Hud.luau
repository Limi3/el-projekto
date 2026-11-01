--!strict
-- Always-on HUD. Shows only what is relevant right now:
--   top:    big XP bar "Level 12 · 340 / 500 XP · 160 to next level"
--   row:    Coins (always) · Stage 37 / 100 (in a stage) · hearts (in runs) · 2× XP timer (if active)
--   boss:   separate boss HP bar (only during a boss)
--   bottom: one onboarding objective at a time
-- Character level, damage and stage completion never share a widget.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Selectors = require(script.Parent.Parent.State.Selectors)
local Format = require(script.Parent.Parent.Util.Format)

local Hud = {}
Hud.__index = Hud

function Hud.new(parent: Instance, Content: any, preview: boolean)
	local S = Content.Strings
	local self = setmetatable({}, Hud)
	self.S = S
	self.lastCoins = nil :: number?
	self.lastXpTotal = nil :: number?

	local root = Kit.new("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	self.root = root

	-- Preview banner (test builds only): permanent and unmissable
	if preview then
		local banner = Kit.new("TextLabel", {
			Name = "PreviewBanner",
			Text = S.t("hud.preview_banner"),
			FontFace = Theme.font.bold,
			TextSize = 16,
			TextColor3 = Theme.color.ink,
			BackgroundColor3 = Theme.color.preview,
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = Theme.zIndex.banner,
			Parent = root,
		})
		Kit.new("UIStroke", { Color = Theme.color.bad, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = banner })
	end

	-- XP block
	local top = preview and 30 or 6
	local xpBox = Kit.new("Frame", { Name = "XP", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, top), Size = UDim2.fromOffset(560, 54), BackgroundTransparency = 1, Parent = root })
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(560, 54), Parent = xpBox })
	local badge = Kit.new("Frame", { Name = "LevelBadge", Size = UDim2.fromOffset(54, 54), BackgroundColor3 = Theme.color.xp, Parent = xpBox })
	Kit.corner(99).Parent = badge
	Kit.stroke(Theme.color.white, 3).Parent = badge
	self.levelNum = Kit.label("1", { font = Theme.font.display, size = 26, color = Theme.color.white, align = Enum.TextXAlignment.Center, frameSize = UDim2.fromScale(1, 1), stroke = true })
	self.levelNum.Parent = badge
	local barArea = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(62, 0), Size = UDim2.new(1, -62, 1, 0), Parent = xpBox })
	self.xpText = Kit.label("", { font = Theme.font.display, size = 17, color = Theme.color.white, frameSize = UDim2.new(1, 0, 0, 24), stroke = true, wrap = false })
	self.xpText.TextTruncate = Enum.TextTruncate.AtEnd
	self.xpText.Parent = barArea
	local track, fill = Kit.bar(Theme.color.xp, 20)
	track.Position = UDim2.fromOffset(0, 28)
	track.Parent = barArea
	Kit.stroke(Theme.color.white, 2).Parent = track
	self.xpFill = fill

	-- Status row
	local row = Kit.new("Frame", { Name = "Row", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, top + 62), Size = UDim2.fromOffset(560, 40), BackgroundTransparency = 1, Parent = root })
	Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = row

	local coins = Kit.pill(Theme.color.coins)
	coins.LayoutOrder = 1
	coins.Parent = row
	local coinIcon = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(24, 24), Parent = coins })
	Icons.draw("coin", coinIcon, Theme.color.coins)
	self.coinText = Kit.label("—", { font = Theme.font.display, size = 20, frameSize = UDim2.new(0, 0, 1, 0), autoSize = Enum.AutomaticSize.X, wrap = false })
	self.coinText.Parent = coins
	self.coinPill = coins

	local stage = Kit.pill(Theme.color.primary)
	stage.LayoutOrder = 2
	stage.Visible = false
	stage.Parent = row
	Kit.label(S.t("hud.stage_label"), { font = Theme.font.bold, size = 15, color = Theme.color.inkSoft, frameSize = UDim2.new(0, 0, 1, 0), autoSize = Enum.AutomaticSize.X, wrap = false }).Parent = stage
	self.stageText = Kit.label("", { font = Theme.font.display, size = 20, frameSize = UDim2.new(0, 0, 1, 0), autoSize = Enum.AutomaticSize.X, wrap = false })
	self.stageText.Parent = stage
	self.stagePill = stage

	local hearts = Kit.new("Frame", { Name = "Hearts", LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Visible = false, Parent = row })
	Kit.list(Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = hearts
	self.hearts = hearts
	self.heartIcons = {} :: { Frame }

	local boost = Kit.pill(Theme.color.xp)
	boost.LayoutOrder = 4
	boost.Visible = false
	boost.Parent = row
	self.boostText = Kit.label("", { font = Theme.font.display, size = 18, color = Theme.color.xp, frameSize = UDim2.new(0, 0, 1, 0), autoSize = Enum.AutomaticSize.X, wrap = false })
	self.boostText.Parent = boost
	self.boostPill = boost

	-- Boss bar (separate from everything else)
	local boss = Kit.new("Frame", { Name = "Boss", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, top + 110), Size = UDim2.fromOffset(480, 58), BackgroundTransparency = 1, Visible = false, Parent = root })
	self.bossName = Kit.label("", { font = Theme.font.display, size = 20, color = Theme.color.white, frameSize = UDim2.new(1, 0, 0, 24), align = Enum.TextXAlignment.Center, stroke = true })
	self.bossName.Parent = boss
	local bTrack, bFill = Kit.bar(Theme.color.bad, 18)
	bTrack.Position = UDim2.fromOffset(0, 28)
	bTrack.Parent = boss
	Kit.stroke(Theme.color.white, 2).Parent = bTrack
	self.bossFill = bFill
	self.bossFrame = boss

	-- Connection / sync status (honest about failures)
	self.status = Kit.label("", { font = Theme.font.bold, size = 16, color = Theme.color.white, align = Enum.TextXAlignment.Center, frameSize = UDim2.fromOffset(520, 30) })
	self.status.AnchorPoint = Vector2.new(0.5, 0)
	self.status.Position = UDim2.new(0.5, 0, 0, top + 178)
	self.status.BackgroundColor3 = Theme.color.shadow
	self.status.BackgroundTransparency = 0.2
	self.status.Visible = false
	Kit.corner(10).Parent = self.status
	self.status.Parent = root

	-- One objective at a time (bottom centre, clear of thumbstick and jump button)
	self.hint = Kit.label("", { font = Theme.font.display, size = 22, color = Theme.color.white, align = Enum.TextXAlignment.Center, frameSize = UDim2.fromOffset(520, 34), stroke = true })
	self.hint.AnchorPoint = Vector2.new(0.5, 1)
	self.hint.Position = UDim2.new(0.5, 0, 1, -24)
	self.hint.Visible = false
	self.hint.Parent = root

	return self
end

function Hud.update(self: any, state: any, now: number)
	local S = self.S
	local xp = Selectors.xp(state)
	if xp.available then
		self.levelNum.Text = tostring(xp.level)
		if xp.isMax then
			self.xpText.Text = S.t("hud.xp_max", { level = xp.level })
		else
			self.xpText.Text = S.t("hud.xp_line", { level = xp.level, current = Format.number(xp.current), needed = Format.number(xp.needed), remaining = Format.number(xp.remaining) })
		end
		Kit.setBar(self.xpFill, xp.fraction, true)
	else
		self.levelNum.Text = "–"
		self.xpText.Text = S.t("ui.loading")
		Kit.setBar(self.xpFill, 0, false)
	end

	local coins = Selectors.coins(state)
	self.coinText.Text = if coins then Format.number(coins) else "—"
	if coins and self.lastCoins and coins > self.lastCoins then
		self:_floatGain(self.coinPill, "+" .. Format.number(coins - self.lastCoins), Theme.color.coins)
	end
	self.lastCoins = coins

	local sp = Selectors.stageProgress(state)
	self.stagePill.Visible = sp.visible
	if sp.visible then
		self.stageText.Text = if sp.skipped then S.t("hud.stage_skipped") else S.t("hud.stage_progress", { done = sp.done, total = sp.total })
	end

	local h = Selectors.hearts(state)
	self.hearts.Visible = h.visible
	if h.visible then
		while #self.heartIcons < h.max do
			local f = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(30, 30), LayoutOrder = #self.heartIcons + 1, Parent = self.hearts })
			Icons.draw("heart", f, Theme.color.bad)
			table.insert(self.heartIcons, f)
		end
		for i, f in self.heartIcons do
			f.Visible = i <= h.max
			for _, child in f:GetChildren() do
				if child:IsA("Frame") then
					child.BackgroundColor3 = if i <= h.current then Theme.color.bad else Theme.color.disabled
				end
			end
		end
	end

	local b = Selectors.boost(state)
	self.boostPill.Visible = b.visible
	if b.visible then
		self.boostText.Text = S.t("hud.boost", { time = Format.duration(b.remaining) }) .. (if b.paused then " " .. S.t("hud.boost_paused") else "")
	end

	local boss = Selectors.boss(state)
	self.bossFrame.Visible = boss.visible
	if boss.visible then
		self.bossName.Text = S.t("hud.boss_hp", { name = S.t(boss.id or "boss.king_puffer"), hp = Format.number(boss.hp), max = Format.number(boss.max) })
		Kit.setBar(self.bossFill, boss.fraction, true)
	end
end

function Hud.setStatus(self: any, status: string)
	local S = self.S
	if status == "ready" then
		self.status.Visible = false
	else
		self.status.Visible = true
		self.status.Text = if status == "connecting" then S.t("hud.connecting") elseif status == "resyncing" then S.t("hud.resyncing") else S.t("hud.unavailable")
		self.status.BackgroundColor3 = if status == "unavailable" then Theme.color.bad else Theme.color.shadow
	end
end

function Hud.setHint(self: any, text: string?)
	self.hint.Visible = text ~= nil
	if text then
		self.hint.Text = text
	end
end

function Hud._floatGain(self: any, anchor: GuiObject, text: string, color: Color3)
	if Kit.reducedMotion then
		return
	end
	local lbl = Kit.label(text, { font = Theme.font.display, size = 20, color = color, align = Enum.TextXAlignment.Center, frameSize = UDim2.fromOffset(120, 26), stroke = true })
	lbl.AnchorPoint = Vector2.new(0.5, 0)
	local pos = anchor.AbsolutePosition - (self.root :: Frame).AbsolutePosition
	lbl.Position = UDim2.fromOffset(pos.X + anchor.AbsoluteSize.X / 2, pos.Y + anchor.AbsoluteSize.Y)
	lbl.Parent = self.root
	local tw = Kit.tween(lbl, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = lbl.Position + UDim2.fromOffset(0, 26), TextTransparency = 1 })
	if tw then
		tw.Completed:Once(function()
			lbl:Destroy()
		end)
	else
		lbl:Destroy()
	end
end

-- Lets the HUD row stay narrow on phones (called by UIController on resize).
function Hud.setCompact(self: any, compact: boolean)
	self.xpText.TextSize = if compact then 15 else 17
end

return Hud
