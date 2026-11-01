--!strict
-- TEST-ONLY preview server (preview-b.project.json). Builds B's world in testMode so the client
-- and world can be checked in Studio before A's production bootstrap exists.
-- A's real Bootstrap.server.luau replaces this in the integrated game; this file is never part
-- of default.project.json.

local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WorldBuilder = require(ServerScriptService:WaitForChild("PopParadeWorld"):WaitForChild("WorldBuilder") :: ModuleScript) :: any

local t0 = os.clock()
local manifest = WorldBuilder.Build(Workspace, {
	seed = 1,
	enabledStageIds = { "stage.rubber.001" },
	testMode = true,
})
WorldBuilder.ApplyLighting(Lighting)

local parts = 0
for _, d in manifest.root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
print(string.format(
	"[PopParade TEST PREVIEW] world built in %.2fs: %d parts, %d balloons, %d checkpoints, %d hazards, %d secrets (server-only)",
	os.clock() - t0,
	parts,
	#manifest.balloons,
	#manifest.checkpoints,
	#manifest.hazards,
	#manifest.secrets
))
for id, report in manifest.validation do
	print(string.format("[PopParade TEST PREVIEW] %s validation ok=%s %s", id, tostring(report.ok), game:GetService("HttpService"):JSONEncode(report.stats)))
end
