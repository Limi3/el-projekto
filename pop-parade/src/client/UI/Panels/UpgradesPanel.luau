--!strict
-- Upgrades: Needle (with Hits and Life), Speed (with the comfortable-speed selector), Attack.
-- Each row shows current -> next, cost, MAX, and why it can't be bought. Values/costs come from
-- A's balance accessor; with no balance available the rows say so instead of guessing.

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Icons = require(script.Parent.Parent.Icons)
local Panel = require(script.Parent.Parent.Panel)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)
local Format = require(script.Parent.Parent.Parent.Util.Format)

local GROUPS = {
	Needle = { "Needle", "Hits", "Life" },
	Speed = { "Speed" },
	Attack = { "Attack" },
}

local UpgradesPanel = {}
UpgradesPanel.__index = UpgradesPanel

function UpgradesPanel.new(ctx: any)
	local S = ctx.S
	local self = setmetatable({ ctx = ctx, rows = {} :: { [string]: any }, focus = "Needle", busy = {} :: { [string]: boolean } }, UpgradesPanel)
	self.panel = Panel.new(ctx.layer, { name = "Upgrades", title = S.t("upgrade.title"), icon = "Needle", color = Theme.upgrade.Needle, closeText = S.t("ui.close") })
	self.notice = Kit.label("", { size = Theme.size.textSmall, color = Theme.color.inkSoft, order = 0 })
	self.notice.Visible = false
	self.notice.Parent = self.panel.body

	for i, id in { "Needle", "Hits", "Life", "Speed", "Attack" } do
		local color = Theme.upgrade[id]
		local card = Panel.card(self.panel.body, i, 104, color)
		local icon = Kit.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(12, 20), Parent = card })
		Kit.corner(14).Parent = icon
		local iconInner = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.7, 0.7), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = icon })
		Icons.draw(id, iconInner, Theme.color.white)
		local info = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(88, 8), Size = UDim2.new(1, -250, 1, -16), Parent = card })
		Kit.list(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left).Parent = info
		local name = Kit.label(S.t("upgrade." .. id), { font = Theme.font.display, size = 22, order = 1, frameSize = UDim2.new(1, 0, 0, 28) })
		name.Parent = info
		local desc = Kit.label(S.t("upgrade." .. id .. ".desc"), { size = 14, color = Theme.color.inkSoft, order = 2, frameSize = UDim2.new(1, 0, 0, 34) })
		desc.Parent = info
		local values = Kit.label("", { font = Theme.font.bold, size = 15, order = 3, frameSize = UDim2.new(1, 0, 0, 22) })
		values.Parent = info
		local buy = Kit.button({
			text = S.t("upgrade.buy"),
			color = color,
			size = UDim2.fromOffset(140, 64),
			onClick = function()
				self:_buy(id)
			end,
		})
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -12, 0.5, 0)
		buy.Parent = card
		self.rows[id] = { card = card, values = values, buy = buy, name = name }
	end

	-- speed selector (choose a comfortable speed up to the owned maximum)
	local sliderRow, setSlider = Kit.slider(S.t("settings.speed"), 12, 16, 1, 16, function(v)
		return tostring(v)
	end, function(v)
		ctx.server:setMoveSpeed(v, function(r)
			if not r.ok then
				ctx.toastError(r.code)
			end
		end)
	end, 6)
	sliderRow.Parent = self.panel.body
	self.speedRow = sliderRow
	self.setSlider = setSlider
	return self
end

function UpgradesPanel._buy(self: any, id: string)
	if self.busy[id] then
		return
	end
	local ctx = self.ctx
	self.busy[id] = true
	Kit.setEnabled(self.rows[id].buy, false)
	ctx.server:buyUpgrade(id, function(r)
		self.busy[id] = nil
		if r.ok then
			ctx.audio:ui("ui.reward")
		else
			ctx.toastError(r.code)
		end
		self:refresh(ctx.client.state)
	end)
end

function UpgradesPanel.openFocused(self: any, focus: string)
	self.focus = if GROUPS[focus] then focus else "Needle"
	local S = self.ctx.S
	self.panel:setTitle(S.t("menu." .. self.focus), self.focus)
	self.panel.header.BackgroundColor3 = Theme.upgrade[self.focus]
	for _, child in self.panel.header:GetChildren() do
		if child:IsA("Frame") and child.BackgroundTransparency == 0 then
			child.BackgroundColor3 = Theme.upgrade[self.focus]
		end
	end
	local visible = {}
	for _, id in GROUPS[self.focus] do
		visible[id] = true
	end
	for id, row in self.rows do
		row.card.Visible = visible[id] == true
	end
	self.speedRow.Visible = self.focus == "Speed"
	self:refresh(self.ctx.client.state)
	self.panel:open()
end

function UpgradesPanel.refresh(self: any, state: any)
	local ctx = self.ctx
	local S = ctx.S
	if not state then
		self.notice.Text = S.t("ui.loading")
		self.notice.Visible = true
		return
	end
	self.notice.Visible = ctx.balance == nil
	if ctx.balance == nil then
		self.notice.Text = S.t("ui.unavailable")
	end
	for id, row in self.rows do
		local r = Selectors.upgrade(state, ctx.balance, id)
		local lvl = S.t("upgrade.level", { level = r.level })
		if not r.available then
			row.values.Text = lvl
			Kit.setButtonText(row.buy, S.t("ui.unavailable"))
			Kit.setEnabled(row.buy, false)
		elseif r.isMax then
			row.values.Text = lvl .. "  ·  " .. S.t("upgrade.current", { value = r.currentText or "?" })
			Kit.setButtonText(row.buy, S.t("upgrade.max"))
			Kit.setEnabled(row.buy, false)
		else
			row.values.Text = string.format("%s  ·  %s → %s", lvl, r.currentText or "?", r.nextText or "?")
			Kit.setButtonText(row.buy, if r.cost then S.t("upgrade.cost", { cost = Format.number(r.cost) }) else S.t("ui.unavailable"))
			Kit.setEnabled(row.buy, r.affordable and not self.busy[id])
		end
	end
	local range = ctx.balance and ctx.balance.speedRange(state)
	if range then
		self.setSlider(state.selectedSpeed or range.max, range.min, range.max)
	end
end

return UpgradesPanel
