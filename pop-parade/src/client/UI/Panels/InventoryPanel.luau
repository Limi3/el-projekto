--!strict
-- Inventory by category: needle skins, trails, wings, pop effects, sounds, accessories, items.
-- Shows owned/equipped state, real accessory bonuses (text supplied by A's state), a local
-- try-on preview for trails/wings/needles, and consumables (Double XP, Skip Token).

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Panel = require(script.Parent.Parent.Panel)
local ItemCard = require(script.Parent.Parent.ItemCard)

local CATS = { "NeedleSkin", "Trail", "Wings", "PopEffect", "Sound", "Accessory", "Consumable" }

local InventoryPanel = {}
InventoryPanel.__index = InventoryPanel

function InventoryPanel.new(ctx: any)
	local S = ctx.S
	local self = setmetatable({ ctx = ctx, cat = "NeedleSkin", cards = {} :: { any }, tabs = {} :: { [string]: TextButton } }, InventoryPanel)
	self.panel = Panel.new(ctx.layer, { name = "Inventory", title = S.t("inv.title"), icon = "Inventory", color = Color3.fromRGB(40, 190, 170), closeText = S.t("ui.close"), width = 620 })
	local tabs = Kit.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 4, LayoutOrder = 0, Parent = self.panel.body })
	Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left).Parent = tabs
	for i, cat in CATS do
		local b = Kit.button({ text = S.t("inv.cat." .. cat), style = "soft", color = Color3.fromRGB(40, 190, 170), size = UDim2.fromOffset(120, 48), order = i, textSize = 15, onClick = function()
			self.cat = cat
			self:refresh(ctx.client.state)
		end })
		b.Parent = tabs
		self.tabs[cat] = b
	end
	self.list = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = self.panel.body })
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = self.list
	return self
end

local function slotOf(Content: any, id: string): string
	return Content.VisualCatalog.get(id).slot
end

function InventoryPanel.refresh(self: any, state: any)
	local ctx = self.ctx
	local S = ctx.S
	local Content = ctx.Content
	for cat, b in self.tabs do
		b.BackgroundColor3 = if cat == self.cat then Color3.fromRGB(40, 190, 170) else Theme.color.paperDim
	end
	for _, c in self.cards do
		c.frame:Destroy()
	end
	table.clear(self.cards)
	if not state then
		return
	end
	local ids = {}
	if self.cat == "Consumable" then
		for id, count in state.consumables or {} do
			if count > 0 then
				table.insert(ids, id)
			end
		end
	elseif self.cat == "Sound" then
		for id in state.owned or {} do
			if Content.AudioCatalog.get(id) then
				table.insert(ids, id)
			end
		end
	else
		for id in state.owned or {} do
			if Content.VisualCatalog.has(id) and slotOf(Content, id) == self.cat then
				table.insert(ids, id)
			end
		end
	end
	table.sort(ids)
	if #ids == 0 then
		local empty = Kit.label(S.t("inv.empty"), { color = Theme.color.inkSoft, align = Enum.TextXAlignment.Center })
		empty.Parent = self.list
		table.insert(self.cards, { frame = empty })
		return
	end
	for i, id in ids do
		local card
		if self.cat == "Consumable" then
			card = ItemCard.new(self.list, Content, id, i, S.t("ui.use"), function()
				if id == "consumable.skip_token" then
					ctx.openPanel("SkipToken")
				else
					local action, payload = ctx.Actions.consumeItem(id)
					ctx.client:request(action, payload, function(r)
						if r.ok then
							ctx.toast(S.t("rewards.boost_remaining", { time = ctx.Format.duration(r.data and r.data.remainingSeconds or 0) }), "good")
						else
							ctx.toastError(r.code)
						end
					end)
				end
			end)
			local d = Content.VisualCatalog.get(id)
			card.status.Text = S.t("inv.count", { count = state.consumables[id] }) .. "  ·  " .. (if d.descKey then S.t(d.descKey) else "")
		else
			local slot = if self.cat == "Sound" then "Sound" else self.cat
			local equipped = state.equipped and state.equipped[slot] == id
			card = ItemCard.new(self.list, Content, id, i, if equipped then S.t("ui.equipped") else S.t("ui.equip"), function()
				local action, payload = ctx.Actions.equipItem(slot, id)
				ctx.client:request(action, payload, function(r)
					if not r.ok then
						ctx.toastError(r.code)
					end
				end)
			end)
			Kit.setEnabled(card.button, not equipped)
			local lines = { if equipped then S.t("ui.equipped") else S.t("ui.owned") }
			if slot == "Accessory" then
				local bonus = state.accessoryBonuses and state.accessoryBonuses[id]
				table.insert(lines, if bonus then S.t("inv.bonus", { text = bonus }) else S.t("ui.loading"))
			elseif slot ~= "Sound" then
				table.insert(lines, S.t("inv.cosmetic_only"))
			end
			card.status.Text = table.concat(lines, "  ·  ")
			if slot == "Trail" or slot == "Wings" or slot == "NeedleSkin" then
				local prev = Kit.button({ text = S.t("ui.preview"), style = "soft", color = Color3.fromRGB(40, 190, 170), size = UDim2.fromOffset(100, 40), onClick = function()
					ctx.cosmetics:preview(slot, id)
				end })
				prev.AnchorPoint = Vector2.new(1, 1)
				prev.Position = UDim2.new(1, -160, 1, -10)
				prev.Parent = card.frame
			end
		end
		table.insert(self.cards, card)
	end
end

return InventoryPanel
