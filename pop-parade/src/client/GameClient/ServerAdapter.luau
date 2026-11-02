--!strict
-- ServerAdapter: the explicit, typed surface UI code uses to talk to A's server.
-- One method per contract action. Each sends an intent (never a balance, reward, price,
-- damage result or purchase confirmation) and calls back with A's result { ok, code?, data? }.
-- Every method returns the request ID so a caller can retry idempotently with the same ID.
--
-- Deliberately ABSENT (server-detected by A, see docs/b/HANDOFF.md):
--   hitBalloon, reachCheckpoint, discoverSecret, damageBoss, grantReward
-- The client only renders A's events for these.
--
-- Payload shapes live in Actions.luau (the single place to change when A's contract lands).

local Actions = require(script.Parent.Actions)

type Result = { ok: boolean, code: string?, data: any? }
type Callback = ((Result) -> ())?

local ServerAdapter = {}
ServerAdapter.__index = ServerAdapter

export type ServerAdapter = typeof(setmetatable({} :: { client: any }, ServerAdapter))

function ServerAdapter.new(client: any): ServerAdapter
	return setmetatable({ client = client }, ServerAdapter)
end

local function send(self: ServerAdapter, action: string, payload: any, cb: Callback, requestId: string?): string
	return self.client:request(action, payload, cb, requestId)
end

-- state ------------------------------------------------------------------
function ServerAdapter.requestState(self: ServerAdapter)
	self.client:resync()
end

function ServerAdapter.requestWorldSnapshot(self: ServerAdapter)
	self.client:requestWorldSnapshot()
end

-- progression ------------------------------------------------------------
function ServerAdapter.buyUpgrade(self: ServerAdapter, upgradeId: string, cb: Callback): string
	local a, p = Actions.buyUpgrade(upgradeId)
	return send(self, a, p, cb)
end

function ServerAdapter.setMoveSpeed(self: ServerAdapter, speed: number, cb: Callback): string
	local a, p = Actions.setMoveSpeed(speed)
	return send(self, a, p, cb)
end

-- inventory / settings ---------------------------------------------------
function ServerAdapter.equipItem(self: ServerAdapter, slot: string, itemId: string?, cb: Callback): string
	local a, p = Actions.equipItem(slot, itemId)
	return send(self, a, p, cb)
end

function ServerAdapter.consumeItem(self: ServerAdapter, itemId: string, cb: Callback): string
	local a, p = Actions.consumeItem(itemId)
	return send(self, a, p, cb)
end

function ServerAdapter.setSetting(self: ServerAdapter, key: string, value: any, cb: Callback): string
	local a, p = Actions.setSetting(key, value)
	return send(self, a, p, cb)
end

-- world / runs -----------------------------------------------------------
function ServerAdapter.enterMode(self: ServerAdapter, mode: string, cb: Callback): string
	local a, p = Actions.enterMode(mode)
	return send(self, a, p, cb)
end

function ServerAdapter.enterStage(self: ServerAdapter, stageId: string, cb: Callback): string
	local a, p = Actions.enterStage(stageId)
	return send(self, a, p, cb)
end

function ServerAdapter.restartRun(self: ServerAdapter, cb: Callback): string
	local a, p = Actions.restartRun()
	return send(self, a, p, cb)
end

function ServerAdapter.useSkipToken(self: ServerAdapter, stageId: string, cb: Callback): string
	local a, p = Actions.useSkipToken(stageId)
	return send(self, a, p, cb)
end

function ServerAdapter.requestExtraJump(self: ServerAdapter, position: Vector3?, cb: Callback): string
	local a, p = Actions.requestExtraJump(position, self.client:serverNow())
	return send(self, a, p, cb)
end

-- rewards ----------------------------------------------------------------
function ServerAdapter.claimDaily(self: ServerAdapter, cb: Callback): string
	local a, p = Actions.claimDaily()
	return send(self, a, p, cb)
end

-- retryId: pass the previous request ID to get the SAME stored outcome after a timeout
function ServerAdapter.requestSpin(self: ServerAdapter, cb: Callback, retryId: string?): string
	local a, p = Actions.requestSpin()
	return send(self, a, p, cb, retryId)
end

-- purchases: A answers with the pass/product ID to prompt; the grant only ever comes from
-- A's receipt processing as a state update, never from this callback.
function ServerAdapter.requestPurchase(self: ServerAdapter, offerId: string, cb: Callback): string
	local a, p = Actions.requestPurchase(offerId)
	return send(self, a, p, cb)
end

-- signals (read-only passthrough) -----------------------------------------
function ServerAdapter.onState(self: ServerAdapter, fn: (any, any) -> ())
	return self.client.StateChanged:Connect(fn)
end

function ServerAdapter.onWorldEvent(self: ServerAdapter, fn: (any) -> ())
	return self.client.WorldEvent:Connect(fn)
end

function ServerAdapter.state(self: ServerAdapter): any
	return self.client.state
end

return ServerAdapter
