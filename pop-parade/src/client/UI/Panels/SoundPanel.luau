--!strict
-- Pop sound picker: five free sounds + optional pack sounds. Preview plays the sound if a real
-- asset exists; otherwise it shows the visual fallback and says the file is missing.

local Kit = require(script.Parent.Parent.Kit)
local Panel = require(script.Parent.Parent.Panel)
local ItemCard = require(script.Parent.Parent.ItemCard)

local SoundPanel = {}
SoundPanel.__index = SoundPanel

function SoundPanel.new(ctx: any)
	local S = ctx.S
	local Audio = ctx.Content.AudioCatalog
	local self = setmetatable({ ctx = ctx, cards = {} :: { [string]: any } }, SoundPanel)
	self.panel = Panel.new(ctx.layer, { name = "Sound", title = S.t("sound.title"), icon = "Sound", color = Color3.fromRGB(120, 120, 255), closeText = S.t("ui.close") })
	local order = 0
	for _, d in Audio.LIST do
		if d.kind == "pop" then
			order += 1
			local id = d.id
			local card = ItemCard.new(self.panel.body, ctx.Content, id, order, S.t("ui.equip"), function()
				self:_equip(id)
			end)
			local preview = Kit.button({ text = S.t("ui.preview"), style = "soft", color = Color3.fromRGB(120, 120, 255), size = UDim2.fromOffset(110, 40), onClick = function()
				ctx.audio:preview(id)
				if Audio.isMissing(id) then
					ctx.toast(S.t("sound.missing"), "info")
				end
			end })
			preview.AnchorPoint = Vector2.new(1, 1)
			preview.Position = UDim2.new(1, -160, 1, -10)
			preview.Parent = card.frame
			card.name.Size = UDim2.new(1, -370, 0, 26)
			card.status.Size = UDim2.new(1, -370, 0, 44)
			self.cards[id] = card
		end
	end
	return self
end

function SoundPanel._equip(self: any, id: string)
	local ctx = self.ctx
	ctx.server:equipItem("Sound", id, function(r)
		if not r.ok then
			ctx.toastError(r.code)
		end
	end)
end

function SoundPanel.refresh(self: any, state: any)
	local S = self.ctx.S
	local Audio = self.ctx.Content.AudioCatalog
	for id, card in self.cards do
		local owned = state and state.owned and state.owned[id] == true
		local equipped = state and state.equipped and state.equipped.Sound == id
		local d = Audio.get(id)
		local lines = {}
		if equipped then
			table.insert(lines, S.t("ui.equipped"))
		elseif owned then
			table.insert(lines, S.t("ui.owned"))
		else
			table.insert(lines, if d and d.premiumPack then S.t("sound.pack") else S.t("ui.locked"))
		end
		if Audio.isMissing(id) then
			table.insert(lines, S.t("sound.missing"))
		end
		card.status.Text = table.concat(lines, " · ")
		Kit.setButtonText(card.button, if equipped then S.t("ui.equipped") else S.t("ui.equip"))
		Kit.setEnabled(card.button, owned and not equipped)
	end
end

return SoundPanel
