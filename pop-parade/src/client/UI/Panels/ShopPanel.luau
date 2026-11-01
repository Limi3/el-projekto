--!strict
-- Shop: today's featured rotation (truthful countdown, no fake scarcity) + the always-available
-- direct-purchase collection. Owned permanent items are hidden; unavailable products are disabled.
-- Prices are live from MarketplaceService for the IDs A authorises.

local Kit = require(script.Parent.Parent.Kit)
local Theme = require(script.Parent.Parent.Theme)
local Panel = require(script.Parent.Parent.Panel)
local ItemCard = require(script.Parent.Parent.ItemCard)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)

local ShopPanel = {}
ShopPanel.__index = ShopPanel

local WHEEL_SKINS = {
	["skin.rubber_twist"] = true,
	["skin.candy_swirl"] = true,
	["skin.chrome_spiral"] = true,
	["skin.neon_helix"] = true,
	["skin.prism_crown"] = true,
}

function ShopPanel.new(ctx: any)
	local S = ctx.S
	local self = setmetatable({ ctx = ctx, cards = {} :: { any } }, ShopPanel)
	self.panel = Panel.new(ctx.layer, { name = "Shop", title = S.t("shop.title"), icon = "Shop", color = Theme.color.primary, closeText = S.t("ui.close"), width = 620 })
	self.countdown = Kit.label("", { font = Theme.font.bold, color = Theme.color.inkSoft, order = 1 })
	self.countdown.Parent = self.panel.body
	self.content = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = self.panel.body })
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = self.content
	return self
end

function ShopPanel.tick(self: any, state: any)
	if not self.panel.isOpen or not state or not state.shop then
		return
	end
	local left = math.max(0, (state.shop.refreshAt or 0) - self.ctx.client:serverNow())
	self.countdown.Text = self.ctx.S.t("shop.refresh_in", { time = self.ctx.Format.duration(left) })
end

function ShopPanel.refresh(self: any, state: any)
	local ctx = self.ctx
	local S = ctx.S
	for _, c in self.cards do
		c.frame:Destroy()
	end
	table.clear(self.cards)
	if not state or not state.shop then
		local l = Kit.label(S.t("ui.loading"), { color = Theme.color.inkSoft })
		l.Parent = self.content
		table.insert(self.cards, { frame = l })
		return
	end
	self:tick(state)
	local order = 0
	local function section(title: string)
		order += 1
		local l = Kit.label(title, { font = Theme.font.display, size = 20, order = order })
		l.Parent = self.content
		table.insert(self.cards, { frame = l })
	end
	local function offerCard(offerId: string)
		local view = Selectors.offer(state, offerId)
		if not view.visible or not view.itemId then
			return
		end
		order += 1
		local offer = state.offers[offerId]
		local card = ItemCard.new(self.content, ctx.Content, view.itemId, order, S.t("ui.price_loading"), function()
			ctx.purchase:buy(offerId)
		end)
		local acq = if WHEEL_SKINS[view.itemId] then S.t("acq.wheel_or_direct") else S.t("acq.purchase")
		card.status.Text = acq .. "\n" .. S.t("shop.direct")
		Kit.setEnabled(card.button, false)
		if not view.purchasable then
			Kit.setButtonText(card.button, S.t("ui.unavailable"))
		else
			ctx.purchase:price(offerId, offer, function(price: number?)
				if card.frame.Parent == nil then
					return
				end
				if price then
					Kit.setButtonText(card.button, S.t("ui.price_robux", { price = price }))
					Kit.setEnabled(card.button, true)
				else
					Kit.setButtonText(card.button, S.t("ui.price_unknown"))
				end
			end)
		end
		table.insert(self.cards, card)
	end
	section(S.t("shop.featured"))
	local any = false
	for _, offerId in state.shop.featured or {} do
		offerCard(offerId)
		any = true
	end
	if not any then
		section(S.t("shop.no_products"))
	end
	section(S.t("shop.collection"))
	for _, offerId in state.shop.collection or {} do
		offerCard(offerId)
	end
end

return ShopPanel
