--!strict
-- Contextual world interactions: local ProximityPrompts on hub stations (kiosks, wheel, rewards,
-- displays, AFK pads) that OPEN the matching panel. Works with keyboard (E), touch (tap) and
-- gamepad (X) out of the box. Never opens a purchase prompt; panels only.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Maid = require(script.Parent.Parent.Util.Maid)

local WorldHints = {}
WorldHints.__index = WorldHints

local function promptFor(kind: string, model: Instance): (string?, string?)
	if kind == "kiosk.upgrades" then
		local up = model:GetAttribute("upgradeId")
		local focus = if up == "Hits" or up == "Life" then "Needle" else up
		return "Upgrades:" .. tostring(focus), "menu." .. tostring(up)
	elseif kind == "wheel" then
		return "Wheel", "menu.Wheel"
	elseif kind == "rewards" then
		return "Rewards", "menu.Rewards"
	elseif kind == "display.cosmetics" then
		return "Shop", "menu.Shop"
	end
	return nil, nil
end

function WorldHints.new(ctx: any)
	local self = setmetatable({ ctx = ctx, maid = Maid.new(), done = {} :: { [Instance]: boolean } }, WorldHints)
	local function scan(world: Instance)
		for _, d in world:GetDescendants() do
			self:_consider(d)
		end
		self.maid:give(world.DescendantAdded:Connect(function(d)
			self:_consider(d)
		end))
	end
	local world = Workspace:FindFirstChild("PopParadeWorld")
	if world then
		scan(world)
	else
		local conn
		conn = Workspace.ChildAdded:Connect(function(c)
			if c.Name == "PopParadeWorld" then
				conn:Disconnect()
				scan(c)
			end
		end)
		self.maid:give(conn)
	end
	return self
end

function WorldHints._consider(self: any, inst: Instance)
	if self.done[inst] or not inst:IsA("Model") then
		return
	end
	local kind = inst:GetAttribute("Kind")
	if type(kind) ~= "string" or inst:GetAttribute("PopParadeMarker") == nil then
		return
	end
	local target, labelKey = promptFor(kind, inst)
	if not target then
		return
	end
	self.done[inst] = true
	local host = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	if not host then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = self.ctx.S.t(labelKey :: string)
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(8, (inst:GetAttribute("Radius") :: number?) or 10)
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = host
	self.maid:give(prompt)
	self.maid:give(prompt.Triggered:Connect(function()
		local name, arg = string.match(target :: string, "^(%w+):?(%w*)$")
		self.ctx.openPanel(name, if arg ~= "" then arg else nil)
	end))
	CollectionService:AddTag(host, "PopParadePromptHost")
end

function WorldHints.destroy(self: any)
	self.maid:clean()
end

return WorldHints
