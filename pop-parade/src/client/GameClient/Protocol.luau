--!strict
-- Pure client-side protocol rules (no Roblox APIs; unit-tested).
-- Message envelopes follow the integration contract:
--   ActionRequest {v, requestId, action, payload}
--   ActionResult  {v, requestId, ok, code, data}
--   StateUpdate   {v, revision, serverTime, state}
--   WorldUpdate   {v, sequence, stageId, snapshot, balloons, events}

local Protocol = {}

Protocol.SCHEMA_VERSION = 1
Protocol.MAX_REQUEST_ID_LENGTH = 40

-- Exactly the contract's allowed actions. The client never sends anything else.
Protocol.ACTIONS = {
	GetState = true,
	GetWorldSnapshot = true,
	BuyUpgrade = true,
	SetMoveSpeed = true,
	EquipItem = true,
	SetSetting = true,
	EnterMode = true,
	EnterStage = true,
	RestartRun = true,
	ClaimDaily = true,
	RequestSpin = true,
	ConsumeItem = true,
	UseSkipToken = true,
	RequestPurchase = true,
	RequestExtraJump = true,
}

-- Stable error codes from the contract (+ TIMEOUT which is client-local).
Protocol.CODES = {
	NOT_READY = true,
	INVALID_REQUEST = true,
	RATE_LIMITED = true,
	INSUFFICIENT_FUNDS = true,
	NOT_OWNED = true,
	LOCKED = true,
	UNAVAILABLE = true,
	ALREADY_CLAIMED = true,
	TIMEOUT = true,
}

export type Envelope = { v: number, requestId: string, action: string, payload: any }

function Protocol.makeEnvelope(requestId: string, action: string, payload: any?): Envelope
	assert(Protocol.ACTIONS[action], "unknown action " .. tostring(action))
	assert(type(requestId) == "string" and #requestId > 0 and #requestId <= Protocol.MAX_REQUEST_ID_LENGTH, "bad requestId")
	return { v = Protocol.SCHEMA_VERSION, requestId = requestId, action = action, payload = if payload == nil then {} else payload }
end

-- Request IDs: "<session>-<counter>", short, unique per session. Session comes from the caller
-- (e.g. a GUID prefix) so retries after reconnect can reuse the SAME id for idempotent actions.
function Protocol.newIdFactory(session: string): () -> string
	local n = 0
	local prefix = string.sub(session, 1, 24)
	return function(): string
		n += 1
		return prefix .. "-" .. tostring(n)
	end
end

-- State revisions: accept only strictly newer revisions of the same schema.
export type RevisionTracker = { revision: number }

function Protocol.newRevisionTracker(): RevisionTracker
	return { revision = -1 }
end

function Protocol.acceptState(tracker: RevisionTracker, msg: any): (boolean, string?)
	if type(msg) ~= "table" then
		return false, "malformed"
	end
	if msg.v ~= Protocol.SCHEMA_VERSION then
		return false, "schema"
	end
	if type(msg.revision) ~= "number" or type(msg.state) ~= "table" then
		return false, "malformed"
	end
	if msg.revision <= tracker.revision then
		return false, "stale"
	end
	tracker.revision = msg.revision
	return true, nil
end

-- World sequence: every WorldUpdate carries a per-player increasing sequence.
-- "apply"  -> in order (or a snapshot that resets the baseline)
-- "stale"  -> older/duplicate, ignore
-- "gap"    -> we missed something: caller must request GetWorldSnapshot
export type SequenceTracker = { last: number?, awaitingSnapshot: boolean }

function Protocol.newSequenceTracker(): SequenceTracker
	return { last = nil, awaitingSnapshot = true }
end

function Protocol.classifyWorld(tracker: SequenceTracker, msg: any): "apply" | "stale" | "gap" | "schema"
	if type(msg) ~= "table" or msg.v ~= Protocol.SCHEMA_VERSION or type(msg.sequence) ~= "number" then
		return "schema"
	end
	local isSnapshot = msg.snapshot ~= nil and msg.snapshot ~= false
	if isSnapshot then
		if tracker.last ~= nil and msg.sequence <= tracker.last then
			return "stale"
		end
		tracker.last = msg.sequence
		tracker.awaitingSnapshot = false
		return "apply"
	end
	if tracker.awaitingSnapshot then
		-- deltas before the first snapshot can't be applied safely
		return "gap"
	end
	local last = tracker.last :: number
	if msg.sequence <= last then
		return "stale"
	end
	if msg.sequence ~= last + 1 then
		tracker.awaitingSnapshot = true
		return "gap"
	end
	tracker.last = msg.sequence
	return "apply"
end

-- Balloon generations: each pop/inflate is processed once per (slot, generation).
-- A pop at generation g means "generation g was popped"; an inflate at generation g means
-- "generation g is now active". Old generations are ignored.
export type GenerationTracker = { slots: { [string]: { gen: number, popped: boolean } } }

function Protocol.newGenerationTracker(): GenerationTracker
	return { slots = {} }
end

function Protocol.applyBalloonEvent(tracker: GenerationTracker, slotId: string, generation: number, kind: "Pop" | "Inflate"): boolean
	local s = tracker.slots[slotId]
	if s == nil then
		s = { gen = -1, popped = false }
		tracker.slots[slotId] = s
	end
	if kind == "Pop" then
		if generation < s.gen or (generation == s.gen and s.popped) then
			return false
		end
		s.gen = generation
		s.popped = true
		return true
	else
		if generation < s.gen or (generation == s.gen and not s.popped) then
			return false
		end
		s.gen = generation
		s.popped = false
		return true
	end
end

-- Snapshot reconciliation: authoritative state replaces local belief for that slot.
function Protocol.syncBalloonState(tracker: GenerationTracker, slotId: string, generation: number, state: string)
	tracker.slots[slotId] = { gen = generation, popped = state ~= "Active" }
end

-- Pending request bookkeeping with deadlines (driven by an injected clock).
export type Pending = { [string]: { action: string, deadline: number, callback: ((result: any) -> ())? } }

function Protocol.expire(pending: Pending, now: number): { { requestId: string, action: string, callback: ((result: any) -> ())? } }
	local out = {}
	for id, p in pending do
		if now >= p.deadline then
			table.insert(out, { requestId = id, action = p.action, callback = p.callback })
		end
	end
	for _, e in out do
		pending[e.requestId] = nil
	end
	table.sort(out, function(a, b)
		return a.requestId < b.requestId
	end)
	return out
end

return Protocol
