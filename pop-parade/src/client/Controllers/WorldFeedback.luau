--!strict
-- World feedback: turns server-confirmed moments into presentation.
--   Checkpoint {checkpointId}      -> that arch's banner turns green + confetti (+ HUD toast in App)
--   run.boss becomes visible        -> "KING PUFFER" intro banner (once per arena entry)
--   BossState phase = "defeated"    -> VICTORY banner
--   run.hearts drops to 0           -> POPPED! defeat banner
--   ParkourFinished {courseId}      -> FINISH banner (event name is a B proposal, see docs/b/HANDOFF.md)
-- Nothing here grants anything: every trigger is a server event or an authoritative state change.

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Maid = require(script.Parent.Parent.Util.Maid)
local Selectors = require(script.Parent.Parent.State.Selectors)

local REACHED = Color3.fromRGB(96, 214, 120)

local WorldFeedback = {}
WorldFeedback.__index = WorldFeedback

function WorldFeedback.new(ctx: any)
	local self = setmetatable({ ctx = ctx, maid = Maid.new(), reached = {} :: { [string]: boolean }, bossShown = false, lastHearts = nil :: number? }, WorldFeedback)
	self.maid:give(ctx.client.WorldEvent:Connect(function(ev)
		self:_event(ev)
	end))
	self.maid:give(ctx.client.StateChanged:Connect(function(state, prev)
		self:_state(state, prev)
	end))
	return self
end

local function findTagged(attr: string, value: string): BasePart?
	local world = Workspace:FindFirstChild("PopParadeWorld")
	if not world then
		return nil
	end
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(attr) == value then
			return d
		end
	end
	return nil
end

function WorldFeedback._event(self: any, ev: any)
	local ctx = self.ctx
	local S = ctx.S
	if ev.type == "Checkpoint" and type(ev.checkpointId) == "string" then
		local id = ev.checkpointId
		local banner = findTagged("PopParadeCheckpointBanner", id)
		local vol = findTagged("PopParadeCheckpoint", id)
		local where = (banner and banner.Position) or (vol and vol.Position)
		if banner and not self.reached[id] then
			TweenService:Create(banner, TweenInfo.new(0.4), { Color = REACHED }):Play()
			banner.Material = Enum.Material.Neon
		end
		if where and not self.reached[id] then
			ctx.effects:celebrate(where, false)
		end
		self.reached[id] = true
	elseif ev.type == "BossState" and ev.phase == "defeated" then
		ctx.banner(S.t("boss.victory_title"), S.t("boss.victory_sub"), "gold", 5)
	elseif ev.type == "ParkourFinished" then
		ctx.banner(S.t("parkour.finish_title"), S.t("parkour.finish_sub"), "good", 4)
		local char = game:GetService("Players").LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			ctx.effects:celebrate(root.Position + Vector3.new(0, 3, 0), true)
		end
	end
end

function WorldFeedback._state(self: any, state: any, prev: any)
	local ctx = self.ctx
	local S = ctx.S
	-- boss intro: first time the boss becomes visible in this arena visit
	local boss = Selectors.boss(state)
	if boss.visible and not self.bossShown and boss.phase ~= "defeated" then
		self.bossShown = true
		ctx.banner(S.t("boss.intro_title"), S.t("boss.intro_sub"), "boss", 4)
	elseif not boss.visible then
		self.bossShown = false
	end
	-- defeat: hearts reach zero during a run (server decides; we only present it)
	local hearts = Selectors.hearts(state)
	if hearts.visible then
		if self.lastHearts and self.lastHearts > 0 and hearts.current == 0 then
			ctx.banner(S.t("run.defeat_title"), S.t("run.defeat_sub"), "bad", 3.5)
		end
		self.lastHearts = hearts.current
	else
		self.lastHearts = nil
	end
	-- a fresh run (new stage) resets which arches are green
	if prev and state.currentStageId ~= prev.currentStageId then
		self.reached = {}
	end
end

function WorldFeedback.destroy(self: any)
	self.maid:clean()
end

return WorldFeedback
