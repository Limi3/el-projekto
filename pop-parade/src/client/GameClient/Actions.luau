--!strict
-- PROVISIONAL payload builders: the ONLY place the client shapes action payloads.
-- A defines the exact discriminated payloads in its contract; until then these are B's proposals
-- (docs/b/CONTRACT_REQUESTS.md, section "Action payloads"). When A's contract lands, fix this file
-- and nothing else needs to change.

local Actions = {}

function Actions.buyUpgrade(upgradeId: string)
	return "BuyUpgrade", { upgradeId = upgradeId }
end

function Actions.setMoveSpeed(speed: number)
	return "SetMoveSpeed", { speed = speed }
end

function Actions.equipItem(slot: string, itemId: string?)
	return "EquipItem", { slot = slot, itemId = itemId }
end

function Actions.setSetting(key: string, value: any)
	return "SetSetting", { key = key, value = value }
end

function Actions.enterMode(mode: string)
	return "EnterMode", { mode = mode }
end

function Actions.enterStage(stageId: string)
	return "EnterStage", { stageId = stageId }
end

function Actions.restartRun()
	return "RestartRun", {}
end

function Actions.claimDaily()
	return "ClaimDaily", {}
end

function Actions.requestSpin()
	return "RequestSpin", {}
end

function Actions.consumeItem(itemId: string)
	return "ConsumeItem", { itemId = itemId }
end

function Actions.useSkipToken(stageId: string)
	return "UseSkipToken", { stageId = stageId }
end

function Actions.requestPurchase(offerId: string)
	return "RequestPurchase", { offerId = offerId }
end

function Actions.requestExtraJump(position: Vector3?, clientTime: number)
	-- intent only: the server validates airborne state, jump budget and plausibility
	return "RequestExtraJump", { t = clientTime, pos = if position then { position.X, position.Y, position.Z } else nil }
end

return Actions
