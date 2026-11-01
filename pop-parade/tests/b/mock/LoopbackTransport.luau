--!strict
-- TEST-ONLY transport wiring GameClient straight to MockServer (synchronous, no Roblox APIs).
-- Used by unit tests and wrapped by MockTransport for Studio previews.
-- `drop` lets tests simulate lost world updates; `available=false` simulates a dead server.

local LoopbackTransport = {}
LoopbackTransport.__index = LoopbackTransport

function LoopbackTransport.new(server: any)
	return setmetatable({ kind = "mock", server = server, available = true, handlers = nil :: any, dropNextWorld = false, sent = {} :: { any } }, LoopbackTransport)
end

function LoopbackTransport.connect(self: any, handlers: any)
	self.handlers = handlers
	self.server:attach({
		actionResult = function(msg)
			if self.available then
				handlers.onActionResult(msg)
			end
		end,
		stateUpdate = function(msg)
			if self.available then
				handlers.onStateUpdate(msg)
			end
		end,
		worldUpdate = function(msg)
			if self.dropNextWorld then
				self.dropNextWorld = false
				return
			end
			if self.available then
				handlers.onWorldUpdate(msg)
			end
		end,
	})
end

function LoopbackTransport.send(self: any, env: any)
	table.insert(self.sent, env)
	if self.available then
		self.server:receive(env)
	end
end

function LoopbackTransport.isAvailable(self: any): boolean
	return self.available
end

return LoopbackTransport
