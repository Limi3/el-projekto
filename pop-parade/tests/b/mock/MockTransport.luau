--!strict
-- TEST-ONLY Studio transport: MockServer + a small local simulation so the preview is playable
-- before A's systems exist. Only loaded by Bootstrap when running in Studio with tests/b mapped.
-- Simulates: auto-attack against the nearest balloon in front, zone changes (hub/stage/parkour),
-- balloon respawns, and King Puffer telegraphs. None of it is authoritative, saved or real.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MockServer = require(script.Parent.MockServer)
local Loopback = require(script.Parent.LoopbackTransport)

local MockTransport = {}
MockTransport.__index = MockTransport

local FIXTURE = "newPlayer" -- change to any name in Fixtures.LIST to preview other states

function MockTransport.new(Content: any, player: Player)
	local defs = {}
	for _, b in Content.Layouts.Hub.get().practice do
		table.insert(defs, b)
	end
	for _, b in Content.Layouts.RubberStage001.get().balloons do
		table.insert(defs, b)
	end
	for _, b in Content.Layouts.Parkour001.get().sideBalloons do
		table.insert(defs, b)
	end
	local server = MockServer.new({ fixture = FIXTURE, now = os.time(), userId = player.UserId, balloonDefs = defs })
	local inner = Loopback.new(server)
	local self = setmetatable({ kind = "mock", inner = inner, server = server, Content = Content, player = player, conn = nil :: RBXScriptConnection?, attackAcc = 0, boss = nil :: any }, MockTransport)
	return self
end

function MockTransport.connect(self: any, handlers: any)
	self.inner:connect(handlers)
	local stage = self.Content.Layouts.RubberStage001.get()
	local parkour = self.Content.Layouts.Parkour001.get()
	local function inside(b: any, p: Vector3): boolean
		return p.X >= b.min.x and p.X <= b.max.x and p.Y >= b.min.y and p.Y <= b.max.y and p.Z >= b.min.z and p.Z <= b.max.z
	end
	self.conn = RunService.Heartbeat:Connect(function(dt)
		local server = self.server
		server:tick(os.time() + (os.clock() % 1))
		local char = self.player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local pos = root.Position
		-- zones
		local zone = if inside(stage.bounds, pos) then "stage" elseif inside(parkour.bounds, pos) then "parkour" else "hub"
		local mode = server.state.mode
		if zone == "stage" and mode ~= "stage" then
			server:receive({ v = 1, requestId = "mock-zone-" .. os.clock(), action = "EnterStage", payload = { stageId = stage.id } })
			server.sink.worldUpdate(server:snapshotMessage())
		elseif zone ~= "stage" and zone ~= mode then
			server:receive({ v = 1, requestId = "mock-zone-" .. os.clock(), action = "EnterMode", payload = { mode = zone } })
			server.sink.worldUpdate(server:snapshotMessage())
		end
		-- auto-attack: nearest active balloon in a forgiving forward cone within reach
		local aps = server.state.stats.attacksPerSecond
		self.attackAcc += dt
		if self.attackAcc >= 1 / aps then
			self.attackAcc = 0
			local look = root.CFrame.LookVector
			local best, bestD = nil, 6.5
			for id, b in server.balloons do
				if b.state == "Active" then
					local d = server.defs[id]
					local to = Vector3.new(d.pos.x, d.pos.y, d.pos.z) - pos
					local dist = to.Magnitude
					if dist < bestD and (dist < 2.5 or look:Dot(to.Unit) > 0.1) then
						best, bestD = id, dist
					end
				end
			end
			if best then
				server:attack(best)
			end
			self:_bossAttack(pos)
		end
		self:_bossTick(pos, stage)
	end)
end

-- Tiny King Puffer loop: windup -> pulse -> knot (vulnerable) -> repeat. Mock timings only.
function MockTransport._bossTick(self: any, pos: Vector3, stage: any)
	local server = self.server
	local c = stage.boss.arenaCenter
	local inArena = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(c.x, 0, c.z)).Magnitude < stage.boss.arenaRadius and server.state.mode == "stage"
	if not inArena then
		return
	end
	local s = server.state
	if not self.boss then
		self.boss = { hp = 900, maxHp = 900, phase = "idle", nextAt = os.clock() + 1.5 }
		s.run = s.run or {}
		s.run.boss = { id = "boss.king_puffer", hp = 900, maxHp = 900, phase = "idle" }
		server:_pushState()
	end
	local b = self.boss
	if b.phase == "defeated" or os.clock() < b.nextAt then
		return
	end
	local now = server.now
	local events: { any } = {}
	if b.phase == "idle" or b.phase == "knot" then
		b.phase = "windup"
		b.nextAt = os.clock() + 1.2
		table.insert(events, { type = "BossTelegraph", bossId = "boss.king_puffer", kind = "windup", startsAt = now, duration = 1.2 })
	elseif b.phase == "windup" then
		b.phase = "pulse"
		b.nextAt = os.clock() + 2.2
		table.insert(events, { type = "BossTelegraph", bossId = "boss.king_puffer", kind = "pulse", startsAt = now, duration = 2.1, params = { ringSpeed = 18, ringMaxRadius = 38 } })
	elseif b.phase == "pulse" then
		b.phase = "knot"
		b.nextAt = os.clock() + 6
		table.insert(events, { type = "BossTelegraph", bossId = "boss.king_puffer", kind = "knot", startsAt = now, duration = 6 })
	end
	table.insert(events, { type = "BossState", bossId = "boss.king_puffer", hp = b.hp, maxHp = b.maxHp, phase = b.phase })
	s.run.boss.phase = b.phase
	server:_pushWorld({}, events)
end

function MockTransport._bossAttack(self: any, _pos: Vector3)
	local b = self.boss
	if not b or b.phase ~= "knot" then
		return
	end
	local server = self.server
	local s = server.state
	b.hp = math.max(0, b.hp - s.stats.damage * 6)
	s.run.boss.hp = b.hp
	local events: { any } = { { type = "Damage", sourceUserId = server.userId, slotId = "boss.king_puffer", generation = 0, amount = s.stats.damage * 6 } }
	if b.hp <= 0 then
		b.phase = "defeated"
		s.run.boss.phase = "defeated"
		table.insert(s.completedStages, s.currentStageId)
		s.owned["wings.basic"] = true
		table.insert(events, { type = "BossState", bossId = "boss.king_puffer", hp = 0, maxHp = b.maxHp, phase = "defeated" })
	end
	server:_pushState()
	server:_pushWorld({}, events)
end

function MockTransport.send(self: any, env: any)
	self.inner:send(env)
end

function MockTransport.isAvailable(self: any): boolean
	return self.inner:isAvailable()
end

function MockTransport.destroy(self: any)
	if self.conn then
		self.conn:Disconnect()
	end
end

-- Silence unused warning for Players in strict mode
local _ = Players

return MockTransport
