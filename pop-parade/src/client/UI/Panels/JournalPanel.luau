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
	self.progress = Kit.label("", { font = Theme.font.display, size = 20, order = 0 })
	self.progress.Parent = self.panel.body
	local track, fill = Kit.bar(Theme.color.golden, 14)
	track.LayoutOrder = 1
	track.Parent = self.panel.body
	self.progressFill = fill
	self.buffs = Kit.label("", { font = Theme.font.bold, size = 16, order = 2, frameSize = UDim2.new(1, 0, 0, 44) })
	self.buffs.Parent = self.panel.body
	self.list = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = self.panel.body })
	return self
end

function JournalPanel.refresh(self: any, state: any)
	local S = self.ctx.S
	if not state then
		return
	end
	local j = Selectors.journal(state, 3)
	local total = #j.found + j.unknownCount
	self.progress.Text = S.t("journal.progress", { found = #j.found, total = total })
	Kit.setBar(self.progressFill, if total > 0 then #j.found / total else 0, true)
	self.buffs.Text = S.t("journal.buffs", { speed = j.buffs.speed, attack = j.buffs.attack, needle = j.buffs.needle })
	self.list:ClearAllChildren()
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = self.list
	local order = 0
	local function row(text: string, found: boolean, desc: string)
		order += 1
		local r = Kit.new("Frame", { BackgroundColor3 = if found then Color3.fromRGB(255, 246, 214) else Theme.color.paperDim, Size = UDim2.new(1, 0, 0, 78), LayoutOrder = order, Parent = self.list })
		Kit.corner(12).Parent = r
		local ic = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(10, 10), Parent = r })
		Icons.draw(if found then "balloon" else "question", ic, if found then Theme.color.golden else Theme.color.disabled)
		local l = Kit.label(text, { font = Theme.font.display, size = 19, frameSize = UDim2.new(1, -70, 0, 30), color = if found then Theme.color.ink else Theme.color.inkSoft })
		l.Position = UDim2.fromOffset(60, 6)
		l.Parent = r
		local d = Kit.label(desc, { size = 14, frameSize = UDim2.new(1, -70, 0, 36), color = Theme.color.inkSoft })
		d.Position = UDim2.fromOffset(60, 36)
		d.TextYAlignment = Enum.TextYAlignment.Top
		d.Parent = r
	end
	for _, id in j.found do
		row(S.t(id) .. "  ·  " .. S.t("journal.found"), true, S.t(id .. ".desc"))
	end
	for _ = 1, j.unknownCount do
		row(S.t("journal.unknown"), false, S.t("journal.unknown_hint"))
	end
end

return JournalPanel
