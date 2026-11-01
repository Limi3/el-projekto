--!strict
-- Purchases, the honest way:
--   * only opens a platform prompt after the player presses Buy AND A's RequestPurchase approves
--     a specific product/pass ID for an approved offer ID
--   * prices are fetched live (MarketplaceService:GetProductInfoAsync) for the ID A authorises;
--     nothing is hardcoded, no dollar conversions
--   * a prompt closing is NOT a grant: the UI waits for A's authoritative state to change

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PurchaseController = {}
PurchaseController.__index = PurchaseController

function PurchaseController.new(ctx: any)
	local self = setmetatable({ ctx = ctx, prices = {} :: { [string]: any }, inFlight = {} :: { [string]: boolean }, waiting = {} :: { [string]: boolean } }, PurchaseController)
	local player = Players.LocalPlayer
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, _passId, purchased)
		if plr == player and purchased then
			ctx.toast(ctx.S.t("ui.purchase_pending"), "info", 5)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, purchased)
		if userId == player.UserId and purchased then
			ctx.toast(ctx.S.t("ui.purchase_pending"), "info", 5)
		end
	end)
	return self
end

-- Live price for an offer. Returns cached value or nil and fires `onReady(price?)` when known.
-- `offer.productId`/`offer.kind` must come from A's state for an authorised offer.
function PurchaseController.price(self: any, offerId: string, offer: any, onReady: (number?) -> ())
	local cached = self.prices[offerId]
	if cached ~= nil then
		onReady(if cached == false then nil else cached)
		return
	end
	local id = offer and tonumber(offer.productId)
	if not id then
		self.prices[offerId] = false
		onReady(nil)
		return
	end
	task.spawn(function()
		local infoType = if offer.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, infoType)
		end)
		local price = if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then info.PriceInRobux else nil
		self.prices[offerId] = if price then price else false
		onReady(price)
	end)
end

function PurchaseController.buy(self: any, offerId: string)
	local ctx = self.ctx
	if self.inFlight[offerId] then
		return
	end
	self.inFlight[offerId] = true
	local action, payload = ctx.Actions.requestPurchase(offerId)
	ctx.client:request(action, payload, function(r)
		self.inFlight[offerId] = nil
		if not r.ok then
			ctx.toastError(r.code)
			return
		end
		local data: any = r.data or {}
		local id = tonumber(data.id)
		if data.mock or not id then
			-- test preview (or misconfigured offer): never open a fake prompt, never fake a grant
			ctx.toast(ctx.S.t("err.UNAVAILABLE"), "info")
			return
		end
		local player = Players.LocalPlayer
		if data.purchaseType == "GamePass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		elseif data.purchaseType == "DeveloperProduct" then
			MarketplaceService:PromptProductPurchase(player, id)
		else
			ctx.toastError("UNAVAILABLE")
		end
	end)
end

function PurchaseController.isBusy(self: any, offerId: string): boolean
	return self.inFlight[offerId] == true
end

return PurchaseController
