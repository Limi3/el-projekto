--!strict
-- POP PARADE: the single production client bootstrap (B-owned).
--
-- Production: talks to A's RemoteEvents through RemoteTransport. If the server isn't there, the
-- HUD says "Server unavailable" and nothing fake is shown.
-- Studio preview only: if (and only if) running in Studio AND the test-only
-- ReplicatedStorage.PopParadeTestB folder exists (mapped by preview-b.project.json), the mock
-- transport is used and a permanent "TEST PREVIEW" banner is shown.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Paths = require(script.Parent.Paths)
local GameClient = require(script.Parent.GameClient)
local RemoteTransport = require(script.Parent.GameClient.RemoteTransport)
local App = require(script.Parent.App)

local Content = Paths.content()

local transport: any
local balance: any? = nil
local preview = false
local mock = Paths.previewMock()
if mock then
	local MockTransport = require(mock:WaitForChild("MockTransport") :: ModuleScript) :: any
	transport = MockTransport.new(Content, Players.LocalPlayer)
	balance = require(mock:WaitForChild("MockBalance") :: ModuleScript) :: any
	preview = true
	warn("[PopParade] TEST PREVIEW: using mock transport (tests/b). Nothing is saved or real.")
else
	transport = RemoteTransport.new()
	balance = Paths.balance()
end

local client = GameClient.new(transport, {
	clock = os.clock,
	session = string.sub(HttpService:GenerateGUID(false), 1, 8),
})

-- UI + controllers subscribe first...
local _app = App.new(client, Content, { balance = balance, preview = preview })

-- ...then the client connects listeners and only afterwards requests the initial state/snapshot.
task.spawn(function()
	client:start()
end)

-- After respawn, re-request the snapshot so views rebuild from authoritative state.
Players.LocalPlayer.CharacterAdded:Connect(function()
	if client.status == "ready" then
		client:requestWorldSnapshot()
	end
end)
