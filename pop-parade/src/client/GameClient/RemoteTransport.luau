--!strict
-- Real transport: the four RemoteEvents A creates under ReplicatedStorage.PopParade.Remotes.
-- If they are missing (server not ready / foundation not merged), the transport reports
-- unavailable. It NEVER fabricates responses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteTransport = {}
RemoteTransport.__index = RemoteTransport

local REMOTE_NAMES = { "ActionRequest", "ActionResult", "StateUpdate", "WorldUpdate" }

function RemoteTransport.new(waitSeconds: number?)
	local self = setmetatable({ kind = "remote", _remotes = nil :: { [string]: RemoteEvent }?, _wait = waitSeconds or 15, _conns = {} :: { RBXScriptConnection } }, RemoteTransport)
	return self
end

local function findRemotes(wait: number): { [string]: RemoteEvent }?
	local root = ReplicatedStorage:WaitForChild("PopParade", wait)
	if not root then
		return nil
	end
	local folder = root:WaitForChild("Remotes", wait)
	if not folder then
		return nil
	end
	local out: { [string]: RemoteEvent } = {}
	for _, name in REMOTE_NAMES do
		local r = folder:WaitForChild(name, wait)
		if not r or not r:IsA("RemoteEvent") then
			return nil
		end
		out[name] = r :: RemoteEvent
	end
	return out
end

function RemoteTransport.connect(self: any, handlers: any)
	local remotes = findRemotes(self._wait)
	if not remotes then
		warn("[PopParade] Remotes not found under ReplicatedStorage.PopParade.Remotes; server unavailable")
		return
	end
	self._remotes = remotes
	table.insert(self._conns, remotes.ActionResult.OnClientEvent:Connect(handlers.onActionResult))
	table.insert(self._conns, remotes.StateUpdate.OnClientEvent:Connect(handlers.onStateUpdate))
	table.insert(self._conns, remotes.WorldUpdate.OnClientEvent:Connect(handlers.onWorldUpdate))
end

function RemoteTransport.send(self: any, envelope: any)
	local remotes = self._remotes
	if remotes then
		remotes.ActionRequest:FireServer(envelope)
	end
end

function RemoteTransport.isAvailable(self: any): boolean
	return self._remotes ~= nil
end

function RemoteTransport.destroy(self: any)
	for _, c in self._conns do
		c:Disconnect()
	end
	table.clear(self._conns)
end

return RemoteTransport
