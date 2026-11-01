--!strict
-- Client app: builds the UI, controllers and the shared ctx, and routes GameClient signals.
-- Created once by the single production client bootstrap (Bootstrap.client.luau).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Hud = require(script.Parent.UI.Hud)
local Menu = require(script.Parent.UI.Menu)
local Toasts = require(script.Parent.UI.Toasts)
local Actions = require(script.Parent.GameClient.Actions)
local Format = require(script.Parent.Util.Format)
local Maid = require(script.Parent.Util.Maid)
local Onboarding = require(script.Parent.State.Onboarding)
local Selectors = require(script.Parent.State.Selectors)

local Panels = script.Parent.UI.Panels
local Controllers = script.Parent.Controllers

local App = {}
App.__index = App

function App.new(client: any, Content: any, opts: { balance: any?, preview: boolean })
	Theme.init(Content)
	local S = Content.Strings
	local player = Players.LocalPlayer
	local self = setmetatable({ client = client, Content = Content, maid = Maid.new(), panels = {} :: { [string]: any }, openName = nil :: string?, flags = { pops = 0, upgradesBought = 0, enteredStage = false, bossSeen = false } }, App)

	local gui = Kit.new("ScreenGui", {
		Name = "PopParadeUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.maid:give(gui)
	local scale = Kit.new("UIScale", { Parent = gui })
	local layer = Kit.new("Frame", { Name = "Panels", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = Theme.zIndex.panel, Parent = gui })
	local tooltipLayer = Kit.new("Frame", { Name = "Tooltips", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 100, Parent = gui })

	self.hud = Hud.new(gui, Content, opts.preview)
	self.toasts = Toasts.new(gui)

	-- shared context handed to every panel/controller
	local ctx: any = {
		client = client,
		Content = Content,
		S = S,
		Actions = Actions,
		Format = Format,
		balance = opts.balance,
		layer = layer,
	}
	function ctx.toast(text: string, kind: string?, seconds: number?)
		self.toasts:show(text, kind, seconds)
	end
	function ctx.toastError(code: string?)
		local key = "err." .. tostring(code or "UNKNOWN")
		self.toasts:show(if S.has(key) then S.t(key) else S.t("err.UNKNOWN"), "bad")
	end
	function ctx.openPanel(name: string, arg: any?)
		self:open(name, arg)
	end
	self.ctx = ctx

	-- controllers (order matters: effects before audio, cosmetics before renderer)
	ctx.effects = require(Controllers.EffectsController).new(Content)
	ctx.audio = require(Controllers.AudioController).new(Content, ctx.effects)
	ctx.camera = require(Controllers.CameraShake).new()
	ctx.damageNumbers = require(Controllers.DamageNumbers).new()
	ctx.cosmetics = require(Controllers.CosmeticsController).new(ctx)
	ctx.purchase = require(Controllers.PurchaseController).new(ctx)
	ctx.settings = {
		applyLocal = function(_: any, key: string, value: any)
			self:_applySetting(key, value)
		end,
	}
	self.renderer = require(Controllers.BalloonRenderer).new(ctx)
	self.boss = require(Controllers.BossPresenter).new(ctx)
	self.jump = require(Controllers.ExtraJumpInput).new(ctx)
	self.hints = require(Controllers.WorldHints).new(ctx)
	for _, c in { ctx.effects, ctx.audio, ctx.cosmetics, self.renderer, self.boss, self.jump, self.hints } do
		self.maid:give(c)
	end

	-- panels
	self.panels.Upgrades = require(Panels.UpgradesPanel).new(ctx)
	self.panels.Sound = require(Panels.SoundPanel).new(ctx)
	self.panels.Inventory = require(Panels.InventoryPanel).new(ctx)
	self.panels.Shop = require(Panels.ShopPanel).new(ctx)
	self.panels.Wheel = require(Panels.WheelPanel).new(ctx)
	self.panels.Rewards = require(Panels.RewardsPanel).new(ctx)
	self.panels.Settings = require(Panels.SettingsPanel).new(ctx)
	self.panels.Journal = require(Panels.JournalPanel).new(ctx)
	self.panels.SkipToken = require(Panels.SkipTokenPanel).new(ctx)

	self.menu = Menu.new(gui, Content, tooltipLayer, function(name: string)
		if name == "Needle" or name == "Speed" or name == "Attack" then
			self:open("Upgrades", name)
		else
			self:open(name)
		end
	end)

	-- responsive scale + compact phone layout
	local function relayout()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local vp = cam.ViewportSize
		local s = math.clamp(vp.Y / Theme.DESIGN_HEIGHT, Theme.MIN_SCALE, Theme.MAX_SCALE)
		if vp.X / s < 900 then
			s = math.max(Theme.MIN_SCALE, vp.X / 900)
		end
		scale.Scale = s
		local compact = vp.Y < 500 or UserInputService.PreferredInput == Enum.PreferredInput.Touch
		self.menu:setCompact(compact)
		self.hud:setCompact(compact)
	end
	relayout()
	local function watchCamera()
		local cam = Workspace.CurrentCamera
		if cam then
			self.maid:give(cam:GetPropertyChangedSignal("ViewportSize"):Connect(relayout))
		end
	end
	watchCamera()
	self.maid:give(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		relayout()
	end))
	self.maid:give(UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(relayout))

	-- close with Escape / gamepad B; gamepad Y focuses the menu
	ContextActionService:BindAction("PopParadeClose", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and self.openName then
			self:close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("PopParadeMenu", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self.menu:focusFirst()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonY)
	self.maid:give(function()
		ContextActionService:UnbindAction("PopParadeClose")
		ContextActionService:UnbindAction("PopParadeMenu")
	end)

	-- GameClient wiring
	self.maid:give(client.StatusChanged:Connect(function(status)
		self.hud:setStatus(status)
	end))
	self.hud:setStatus(client.status)
	self.maid:give(client.StateChanged:Connect(function(state, prev)
		self:_onState(state, prev)
	end))
	self.maid:give(client.WorldEvent:Connect(function(ev)
		self:_onWorldEvent(ev)
	end))
	self.maid:give(client.SchemaMismatch:Connect(function()
		ctx.toastError("UNAVAILABLE")
	end))

	-- 1 Hz UI ticks (timers) and request timeouts
	local acc = 0
	self.maid:give(RunService.Heartbeat:Connect(function(dt)
		acc += dt
		client:tick()
		if acc >= 1 then
			acc = 0
			local st = client.state
			if st then
				self.hud:update(st, client:serverNow())
				self.panels.Shop:tick(st)
				self.panels.Rewards:tick(st)
			end
		end
	end))
	self.hud:update(nil, 0)
	self.hud:setHint(S.t("hint.first"))
	return self
end

function App.open(self: any, name: string, arg: any?)
	if self.openName and self.openName ~= name then
		self:close()
	end
	local p = self.panels[name]
	if not p then
		return
	end
	self.openName = name
	p.panel._onClose = function()
		if self.openName == name then
			self.openName = nil
			self.menu:focusFirst()
		end
	end
	if name == "Upgrades" then
		p:openFocused(arg or "Needle")
	else
		p:refresh(self.client.state)
		p.panel:open()
	end
end

function App.close(self: any)
	local name = self.openName
	if name and self.panels[name] then
		self.panels[name].panel:close()
	end
	self.openName = nil
end

function App._applySetting(self: any, key: string, value: any)
	local ctx = self.ctx
	if key == "reducedEffects" then
		local v = value == true
		Kit.reducedMotion = v
		ctx.effects:setReduced(v)
		ctx.damageNumbers:setReduced(v)
		ctx.cosmetics:setReduced(v)
		self.renderer:setReduced(v)
		local shake = self.client.state and self.client.state.settings and self.client.state.settings.shake ~= false
		self.boss:setFlags(v, shake)
		ctx.camera:setEnabled(shake and not v)
	elseif key == "shake" then
		local reduced = Kit.reducedMotion
		self.boss:setFlags(reduced, value == true)
		ctx.camera:setEnabled(value == true and not reduced)
	elseif key == "sfx" then
		ctx.audio:setVolumes(value, nil)
	elseif key == "music" then
		ctx.audio:setVolumes(nil, value)
	end
end

function App._onState(self: any, state: any, prev: any)
	local S = self.Content.Strings
	local ctx = self.ctx
	self.hud:update(state, self.client:serverNow())
	-- settings from the server (authoritative copy)
	local st = state.settings or {}
	local pst = prev and prev.settings or {}
	for _, key in { "reducedEffects", "shake", "sfx", "music" } do
		if prev == nil or st[key] ~= pst[key] then
			self:_applySetting(key, st[key])
		end
	end
	-- onboarding flags derived from authoritative changes
	if prev then
		for id, up in state.upgrades or {} do
			local before = prev.upgrades and prev.upgrades[id]
			if type(up) == "table" and type(before) == "table" and up.level > before.level then
				self.flags.upgradesBought += 1
			end
		end
	end
	if state.mode == "stage" then
		self.flags.enteredStage = true
	end
	if Selectors.boss(state).visible then
		self.flags.bossSeen = true
	end
	local hint = Onboarding.next(state, ctx.balance, self.flags)
	self.hud:setHint(if hint then S.t(hint) else nil)
	-- menu badges: claimable daily, affordable upgrade, spin ticket
	local daily = Selectors.dailyTrack(state, self.client:serverNow())
	self.menu:setBadge("Rewards", daily.canClaim)
	self.menu:setBadge("Wheel", (state.spinTickets or 0) > 0)
	self.menu:setBadge("More", daily.canClaim or (state.spinTickets or 0) > 0)
	local affordable = Selectors.firstAffordableUpgrade(state, ctx.balance)
	for _, id in { "Needle", "Speed", "Attack" } do
		local hit = affordable == id or (id == "Needle" and (affordable == "Hits" or affordable == "Life"))
		self.menu:setBadge(id, hit)
	end
	-- refresh the open panel
	if self.openName then
		local p = self.panels[self.openName]
		p:refresh(state)
	end
end

function App._onWorldEvent(self: any, ev: any)
	local S = self.Content.Strings
	local ctx = self.ctx
	if ev.type == "Pop" and (ev.sourceUserId == nil or ev.sourceUserId == Players.LocalPlayer.UserId) then
		self.flags.pops += 1
		if self.flags.pops == 3 and self.client.state then
			self:_onState(self.client.state, self.client.state)
		end
	elseif ev.type == "Checkpoint" then
		ctx.toast(S.t("checkpoint.reached"), "good", 2)
		ctx.audio:ui("sfx.checkpoint")
	elseif ev.type == "SecretFound" then
		local stat = if ev.stat then S.t("stat." .. ev.stat) else ""
		ctx.toast(S.t("secret.found_title") .. "\n" .. S.t("secret.found_body", { name = S.t(ev.secretId or ""), stat = stat }), "gold", 6)
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			ctx.effects:celebrate(root.Position + Vector3.new(0, 3, 0), true)
		end
		ctx.audio:ui("sfx.secret_found")
	end
end

function App.destroy(self: any)
	self.maid:clean()
end

return App
