--!strict
-- GameClient: the ONE adapter between UI/controllers and the server.
-- Works with any transport implementing the Transport type (real RemoteTransport or the test-only
-- MockTransport in tests/b/mock). UI code never touches remotes directly.
--
-- Rules implemented here (contract "Network surface"):
--   * listeners are connected BEFORE the initial GetState / GetWorldSnapshot requests
--   * stale StateUpdate revisions are ignored; schema mismatches are reported, not applied
--   * WorldUpdate sequence gaps trigger a snapshot resync
--   * requests time out gracefully (code TIMEOUT); late results for idempotent actions are still
--     delivered to `LateResult` so e.g. a spin outcome is recovered instead of rerolled
--   * no fake data: if the server is unavailable, status says so and state stays nil/last-known

local Protocol = require(script.Protocol)
local Signal = require(script.Parent.Util.Signal)

export type Transport = {
	kind: string, -- "remote" | "mock"
	connect: (self: any, handlers: Handlers) -> (),
	send: (self: any, envelope: Protocol.Envelope) -> (),
	isAvailable: (self: any) -> boolean,
}

export type Handlers = {
	onActionResult: (msg: any) -> (),
	onStateUpdate: (msg: any) -> (),
	onWorldUpdate: (msg: any) -> (),
}

export type Status = "connecting" | "ready" | "resyncing" | "unavailable"

export type Result = { ok: boolean, code: string?, data: any, requestId: string }

local GameClient = {}
GameClient.__index = GameClient
GameClient.Protocol = Protocol

local DEFAULT_TIMEOUT = 8
local IDEMPOTENT_ACTIONS = { RequestSpin = true, ClaimDaily = true, ConsumeItem = true, UseSkipToken = true, BuyUpgrade = true, RequestPurchase = true }

export type GameClient = typeof(setmetatable(
	{} :: {
		transport: Transport,
		clock: () -> number,
		timeout: number,
		status: Status,
		state: any?,
		serverTimeOffset: number,
		stageId: string?,
		balloonStates: { [string]: any },
		StateChanged: Signal.Signal<any, any?>,
		StatusChanged: Signal.Signal<Status>,
		WorldSnapshot: Signal.Signal<string?, { any }>,
		BalloonState: Signal.Signal<any>,
		WorldEvent: Signal.Signal<any>,
		LateResult: Signal.Signal<string, Result>,
		SchemaMismatch: Signal.Signal<number?>,
		_revision: Protocol.RevisionTracker,
		_sequence: Protocol.SequenceTracker,
		_generations: Protocol.GenerationTracker,
		_pending: Protocol.Pending,
		_late: { [string]: string },
		_nextId: () -> string,
		_snapshotInFlight: boolean,
		_started: boolean,
		_lastHeard: number,
	},
	GameClient
))

function GameClient.new(transport: Transport, opts: { clock: () -> number, session: string, timeout: number? }): GameClient
	local self = setmetatable({
		transport = transport,
		clock = opts.clock,
		timeout = opts.timeout or DEFAULT_TIMEOUT,
		status = "connecting" :: Status,
		state = nil,
		serverTimeOffset = 0,
		stageId = nil,
		balloonStates = {},
		StateChanged = Signal.new(),
		StatusChanged = Signal.new(),
		WorldSnapshot = Signal.new(),
		BalloonState = Signal.new(),
		WorldEvent = Signal.new(),
		LateResult = Signal.new(),
		SchemaMismatch = Signal.new(),
		_revision = Protocol.newRevisionTracker(),
		_sequence = Protocol.newSequenceTracker(),
		_generations = Protocol.newGenerationTracker(),
		_pending = {},
		_late = {},
		_nextId = Protocol.newIdFactory(opts.session),
		_snapshotInFlight = false,
		_started = false,
		_lastHeard = opts.clock(),
	}, GameClient)
	return self :: any
end

function GameClient._setStatus(self: GameClient, status: Status)
	if self.status ~= status then
		self.status = status
		self.StatusChanged:Fire(status)
	end
end

function GameClient.start(self: GameClient)
	assert(not self._started, "GameClient already started")
	self._started = true
	-- 1) listeners first
	self.transport:connect({
		onActionResult = function(msg)
			self:_onActionResult(msg)
		end,
		onStateUpdate = function(msg)
			self:_onStateUpdate(msg)
		end,
		onWorldUpdate = function(msg)
			self:_onWorldUpdate(msg)
		end,
	})
	-- 2) then initial requests
	if not self.transport:isAvailable() then
		self:_setStatus("unavailable")
		return
	end
	self:resync()
end

-- Full resync: fresh state + world snapshot (after reconnect, gaps or respawn).
function GameClient.resync(self: GameClient)
	if not self.transport:isAvailable() then
		self:_setStatus("unavailable")
		return
	end
	if self.state ~= nil then
		self:_setStatus("resyncing")
	end
	self:request("GetState", {}, function(result: Result)
		if result.ok and type(result.data) == "table" and result.data.state then
			-- GetState may return {revision, serverTime, state}; treat it like a StateUpdate
			self:_onStateUpdate({ v = Protocol.SCHEMA_VERSION, revision = result.data.revision, serverTime = result.data.serverTime, state = result.data.state })
		elseif not result.ok then
			self:_setStatus(if result.code == "TIMEOUT" then "unavailable" else self.status)
		end
	end)
	self:requestWorldSnapshot()
end

function GameClient.requestWorldSnapshot(self: GameClient)
	if self._snapshotInFlight then
		return
	end
	self._snapshotInFlight = true
	self:request("GetWorldSnapshot", { stageId = self.stageId }, function(result: Result)
		self._snapshotInFlight = false
		if result.ok and type(result.data) == "table" and result.data.sequence then
			self:_onWorldUpdate(result.data)
		end
	end)
end

-- Sends an action. Returns the requestId. `callback` gets exactly one Result (ok, error or TIMEOUT).
-- Pass `requestId` to RETRY an idempotent action with the same id (server returns the same outcome).
function GameClient.request(self: GameClient, action: string, payload: any?, callback: ((Result) -> ())?, requestId: string?): string
	local id = requestId or self._nextId()
	if not self.transport:isAvailable() then
		if callback then
			callback({ ok = false, code = "NOT_READY", data = nil, requestId = id })
		end
		return id
	end
	local env = Protocol.makeEnvelope(id, action, payload)
	self._pending[id] = { action = action, deadline = self.clock() + self.timeout, callback = callback }
	self.transport:send(env)
	return id
end

-- Call regularly (e.g. every Heartbeat or 0.25s) to fire timeouts.
function GameClient.tick(self: GameClient)
	local now = self.clock()
	for _, e in Protocol.expire(self._pending, now) do
		if IDEMPOTENT_ACTIONS[e.action] then
			self._late[e.requestId] = e.action
		end
		if e.callback then
			e.callback({ ok = false, code = "TIMEOUT", data = nil, requestId = e.requestId })
		end
		if e.action == "GetState" and self.state == nil then
			self:_setStatus("unavailable")
		end
	end
	if not self.transport:isAvailable() and self.status ~= "unavailable" then
		self:_setStatus("unavailable")
	end
end

function GameClient.serverNow(self: GameClient): number
	return self.clock() + self.serverTimeOffset
end

function GameClient._onActionResult(self: GameClient, msg: any)
	if type(msg) ~= "table" or type(msg.requestId) ~= "string" then
		return
	end
	self._lastHeard = self.clock()
	local result: Result = { ok = msg.ok == true, code = msg.code, data = msg.data, requestId = msg.requestId }
	local p = self._pending[msg.requestId]
	if p then
		self._pending[msg.requestId] = nil
		if p.callback then
			p.callback(result)
		end
	elseif self._late[msg.requestId] then
		self._late[msg.requestId] = nil
		self.LateResult:Fire(msg.requestId, result)
	end
end

function GameClient._onStateUpdate(self: GameClient, msg: any)
	local ok, why = Protocol.acceptState(self._revision, msg)
	if not ok then
		if why == "schema" then
			self.SchemaMismatch:Fire(if type(msg) == "table" then msg.v else nil)
		end
		return
	end
	self._lastHeard = self.clock()
	if type(msg.serverTime) == "number" then
		self.serverTimeOffset = msg.serverTime - self.clock()
	end
	local prev = self.state
	self.state = msg.state
	local stage = msg.state.currentStageId
	if stage ~= self.stageId then
		self.stageId = stage
		self._sequence = Protocol.newSequenceTracker()
		self:requestWorldSnapshot()
	end
	self:_setStatus("ready")
	self.StateChanged:Fire(msg.state, prev)
end

function GameClient._onWorldUpdate(self: GameClient, msg: any)
	local verdict = Protocol.classifyWorld(self._sequence, msg)
	if verdict == "schema" then
		self.SchemaMismatch:Fire(if type(msg) == "table" then msg.v else nil)
		return
	elseif verdict == "stale" then
		return
	elseif verdict == "gap" then
		self:requestWorldSnapshot()
		return
	end
	self._lastHeard = self.clock()
	local isSnapshot = msg.snapshot ~= nil and msg.snapshot ~= false
	if isSnapshot then
		table.clear(self.balloonStates)
		for _, b in msg.balloons or {} do
			self.balloonStates[b.slotId] = b
			Protocol.syncBalloonState(self._generations, b.slotId, b.generation, b.state)
		end
		self.WorldSnapshot:Fire(msg.stageId, msg.balloons or {})
	else
		for _, b in msg.balloons or {} do
			local cur = self.balloonStates[b.slotId]
			if cur == nil or b.generation >= cur.generation then
				self.balloonStates[b.slotId] = b
				self.BalloonState:Fire(b)
			end
		end
	end
	for _, ev in msg.events or {} do
		if ev.type == "Pop" or ev.type == "Inflate" then
			if Protocol.applyBalloonEvent(self._generations, ev.slotId, ev.generation, ev.type) then
				self.WorldEvent:Fire(ev)
			end
		else
			self.WorldEvent:Fire(ev)
		end
	end
end

function GameClient.destroy(self: GameClient)
	self.StateChanged:DisconnectAll()
	self.StatusChanged:DisconnectAll()
	self.WorldSnapshot:DisconnectAll()
	self.BalloonState:DisconnectAll()
	self.WorldEvent:DisconnectAll()
	self.LateResult:DisconnectAll()
	self.SchemaMismatch:DisconnectAll()
	table.clear(self._pending)
end

return GameClient
