--!strict
-- Skip Token confirmation. States EXACTLY what is bypassed and what is NOT awarded, before the
-- player spends the token. Disabled at the last available stage (tokens are kept).

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Panel = require(script.Parent.Parent.Panel)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)

local SkipTokenPanel = {}
SkipTokenPanel.__index = SkipTokenPanel

function SkipTokenPanel.new(ctx: any)
	local S = ctx.S
	local self = setmetatable({ ctx = ctx, busy = false }, SkipTokenPanel)
	self.panel = Panel.new(ctx.layer, { name = "SkipToken", title = S.t("skip.title"), icon = "skip", color = Theme.color.secondary, closeText = S.t("ui.close"), width = 520, height = 470 })
	local body = self.panel.body
	self.have = Kit.label("", { font = Theme.font.bold, order = 1 })
	self.have.Parent = body
	self.text = Kit.label("", { size = 17, order = 2, frameSize = UDim2.new(1, 0, 0, 52) })
	self.text.Parent = body
	self.notAwarded = Kit.label(S.t("skip.not_awarded"), { size = 16, color = Theme.color.bad, font = Theme.font.bold, order = 3, frameSize = UDim2.new(1, 0, 0, 72) })
	self.notAwarded.Parent = body
	Kit.label(S.t("skip.revisit"), { size = 15, color = Theme.color.inkSoft, order = 4 }).Parent = body
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 5, Parent = body })
	Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center).Parent = row
	Kit.button({ text = S.t("ui.cancel"), style = "soft", color = Theme.color.inkSoft, size = UDim2.fromOffset(200, 56), order = 1, onClick = function()
		self.panel:close()
	end }).Parent = row
	self.confirm = Kit.button({ text = S.t("ui.confirm"), color = Theme.color.secondary, size = UDim2.fromOffset(200, 56), order = 2, onClick = function()
		self:_confirm()
	end })
	self.confirm.Parent = row
	return self
end

function SkipTokenPanel.refresh(self: any, state: any)
	local S = self.ctx.S
	local v = Selectors.skipToken(state)
	self.have.Text = S.t("skip.have", { count = v.count })
	if v.reason == "last_stage" then
		self.text.Text = S.t("skip.last_stage")
	else
		self.text.Text = S.t("skip.body", { stage = S.t(v.stageId or "stage.rubber.001") })
	end
	Kit.setEnabled(self.confirm, v.canUse and not self.busy)
end

function SkipTokenPanel._confirm(self: any)
	local ctx = self.ctx
	local v = Selectors.skipToken(ctx.client.state)
	if not v.canUse or self.busy or not v.stageId then
		return
	end
	self.busy = true
	Kit.setEnabled(self.confirm, false)
	ctx.server:useSkipToken(v.stageId, function(r)
		self.busy = false
		if r.ok then
			self.panel:close()
		else
			ctx.toastError(r.code)
			self:refresh(ctx.client.state)
		end
	end)
end

return SkipTokenPanel
