--!strict
-- Secret journal: found secrets by name, undiscovered ones as "???" silhouettes, and the
-- permanent account-wide bonus totals. No locations or solutions here (spoilers live in dev docs).

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Icons = require(script.Parent.Parent.Icons)
local Panel = require(script.Parent.Parent.Panel)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)

local JournalPanel = {}
JournalPanel.__index = JournalPanel

function JournalPanel.new(ctx: any)
	local S = ctx.S
	local self = setmetatable({ ctx = ctx }, JournalPanel)
	self.panel = Panel.new(ctx.layer, { name = "Journal", title = S.t("journal.title"), icon = "Journal", color = Theme.color.golden, closeText = S.t("ui.close"), width = 520, height = 500 })
	self.buffs = Kit.label("", { font = Theme.font.bold, size = 16, order = 1, frameSize = UDim2.new(1, 0, 0, 44) })
	self.buffs.Parent = self.panel.body
	self.list = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = self.panel.body })
	return self
end

function JournalPanel.refresh(self: any, state: any)
	local S = self.ctx.S
	if not state then
		return
	end
	local j = Selectors.journal(state, 3)
	self.buffs.Text = S.t("journal.buffs", { speed = j.buffs.speed, attack = j.buffs.attack, needle = j.buffs.needle })
	self.list:ClearAllChildren()
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = self.list
	local order = 0
	local function row(text: string, found: boolean)
		order += 1
		local r = Kit.new("Frame", { BackgroundColor3 = if found then Color3.fromRGB(255, 246, 214) else Theme.color.paperDim, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = order, Parent = self.list })
		Kit.corner(12).Parent = r
		local ic = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(10, 10), Parent = r })
		Icons.draw(if found then "balloon" else "question", ic, if found then Theme.color.golden else Theme.color.disabled)
		local l = Kit.label(text, { font = Theme.font.display, size = 19, frameSize = UDim2.new(1, -70, 1, 0), color = if found then Theme.color.ink else Theme.color.inkSoft })
		l.Position = UDim2.fromOffset(60, 0)
		l.Parent = r
	end
	for _, id in j.found do
		row(S.t(id) .. "  ·  " .. S.t("journal.found"), true)
	end
	for _ = 1, j.unknownCount do
		row(S.t("journal.unknown"), false)
	end
end

return JournalPanel
