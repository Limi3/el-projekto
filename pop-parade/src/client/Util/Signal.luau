--!strict
-- Tiny synchronous signal (no Roblox dependency, so pure modules and tests can use it).
-- Handlers run in connection order; a failing handler is reported and does not stop the others.

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { any } }, Signal)
	return self :: any
end

function Signal.Connect(self: any, fn: any): Connection
	local conn = { Connected = true, _fn = fn }
	function conn.Disconnect(c: any)
		c.Connected = false
		local list = self._handlers
		local i = table.find(list, c)
		if i then
			table.remove(list, i)
		end
	end
	table.insert(self._handlers, conn)
	return conn :: any
end

function Signal.Once(self: any, fn: any): Connection
	local conn: any
	conn = Signal.Connect(self, function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal.Fire(self: any, ...: any)
	local snapshot: { any } = table.clone(self._handlers)
	for _, c in snapshot do
		if c.Connected then
			local ok, err = pcall(c._fn, ...)
			if not ok then
				warn("[PopParade] signal handler error: " .. tostring(err))
			end
		end
	end
end

function Signal.DisconnectAll(self: any)
	for _, c in self._handlers do
		c.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
