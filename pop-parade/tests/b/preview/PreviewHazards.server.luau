--!strict
-- TEST-ONLY hazard motion for the Studio preview. In the real game A animates and evaluates
-- hazards on the server by hazard ID (contract: B builds geometry + attributes only). This
-- script exists so the preview *looks and plays* like the stage before A's systems exist.
-- Uses each hazard's own layout params (rpm, period, telegraph, active, push, phase).
-- Never part of default.project.json.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Content = require(ReplicatedStorage:WaitForChild("PopParade"):WaitForChild("Content") :: ModuleScript) :: any

local world = Workspace:WaitForChild("PopParadeWorld", 30)
if not world then
	warn("[PopParade TEST PREVIEW] hazards: world not found, hazard motion disabled")
	return
end

local params: { [string]: any } = {}
for _, h in Content.Layouts.RubberStage001.get().hazards do
	params[h.id] = h.params
end

type Sweeper = { model: Model, pivot: CFrame, parts: { { part: BasePart, offset: CFrame } }, rpm: number }
type Vent = { grate: BasePart, rimColor: { [BasePart]: Color3 }, rim: { BasePart }, p: any, emitter: ParticleEmitter, wasActive: boolean }

local sweepers: { Sweeper } = {}
local vents: { Vent } = {}

for _, m in world:GetDescendants() do
	if m:IsA("Model") and m:GetAttribute("PopParadeHazard") then
		local p = params[m:GetAttribute("PopParadeHazard") :: string]
		local key = m:GetAttribute("BehaviorKey")
		if key == "sweeper" and p then
			local pivotPart = m:FindFirstChild("Pivot") :: BasePart?
			if pivotPart then
				local pivot = pivotPart.CFrame
				local list = {}
				for _, part in m:GetChildren() do
					if part:IsA("BasePart") and (part.Name == "Arm" or part.Name == "ArmTip") then
						part.Anchored = true
						table.insert(list, { part = part, offset = pivot:ToObjectSpace(part.CFrame) })
					end
				end
				table.insert(sweepers, { model = m, pivot = pivot, parts = list, rpm = p.rpm or 9 })
			end
		elseif key == "puff_vent" and p then
			local grate = m.PrimaryPart
			if grate then
				local rim = {}
				local colors = {}
				local rimFolder = m:FindFirstChild("Rim")
				for _, part in (if rimFolder then rimFolder:GetChildren() else {}) do
					if part:IsA("BasePart") then
						table.insert(rim, part)
						colors[part] = part.Color
					end
				end
				local e = Instance.new("ParticleEmitter")
				e.Rate = 0
				e.Lifetime = NumberRange.new(0.6, 1)
				e.Speed = NumberRange.new(18, 26)
				e.SpreadAngle = Vector2.new(12, 12)
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
				e.Color = ColorSequence.new(Color3.new(1, 1, 1))
				e.EmissionDirection = Enum.NormalId.Top
				-- world-upright attachment so "Top" means up (the grate cylinder is rotated)
				local nozzle = Instance.new("Attachment")
				nozzle.Name = "PreviewPuff"
				nozzle.Parent = grate
				nozzle.WorldCFrame = CFrame.new(grate.Position + Vector3.new(0, 0.4, 0))
				e.Parent = nozzle
				table.insert(vents, { grate = grate, rim = rim, rimColor = colors, p = p, emitter = e, wasActive = false })
			end
		end
	end
end

print(string.format("[PopParade TEST PREVIEW] hazard motion: %d sweepers, %d vents (test-only, A owns real hazards)", #sweepers, #vents))

local WARN = Color3.fromRGB(255, 190, 40)
local ACTIVE = Color3.fromRGB(255, 255, 255)
local t0 = os.clock()

RunService.Heartbeat:Connect(function()
	local t = os.clock() - t0
	for _, s in sweepers do
		local rot = s.pivot * CFrame.Angles(0, t * s.rpm / 60 * math.pi * 2, 0)
		for _, e in s.parts do
			e.part.CFrame = rot * e.offset
		end
	end
	for _, v in vents do
		local p = v.p
		local cycle = (t + (p.phase or 0)) % (p.period or 4)
		local telegraph = cycle < (p.telegraph or 1)
		local active = not telegraph and cycle < (p.telegraph or 1) + (p.active or 1.2)
		for _, r in v.rim do
			r.Color = if telegraph then (if math.floor(cycle * 8) % 2 == 0 then WARN else v.rimColor[r]) elseif active then ACTIVE else v.rimColor[r]
			r.Material = if telegraph or active then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
		if active and not v.wasActive then
			v.emitter:Emit(24)
		end
		v.wasActive = active
		if active then
			-- push players standing over the vent upward (the "puff")
			local top = v.grate.Position
			for _, plr in Players:GetPlayers() do
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local d = root.Position - top
					if Vector2.new(d.X, d.Z).Magnitude < v.grate.Size.Z / 2 + 0.5 and d.Y > -1 and d.Y < 8 then
						root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, p.push or 40, root.AssemblyLinearVelocity.Z)
					end
				end
			end
		end
	end
end)
