--!strict
-- Generic object pool with a hard cap. `create` makes a new object, `reset` hides/parks it.
-- When the cap is reached, acquire() returns nil and callers skip the effect (graceful under load).

export type Pool<T> = {
	acquire: (self: Pool<T>) -> T?,
	release: (self: Pool<T>, obj: T) -> (),
	stats: (self: Pool<T>) -> { free: number, live: number, created: number, cap: number },
	destroy: (self: Pool<T>) -> (),
}

local Pool = {}
Pool.__index = Pool

function Pool.new<T>(create: () -> T, reset: (T) -> (), cap: number, destroyFn: ((T) -> ())?): Pool<T>
	return setmetatable({
		_create = create,
		_reset = reset,
		_destroy = destroyFn,
		_free = {} :: { T },
		_live = {} :: { [T]: boolean },
		_liveCount = 0,
		_created = 0,
		_cap = cap,
	}, Pool) :: any
end

function Pool.acquire(self: any): any
	local obj = table.remove(self._free)
	if obj == nil then
		if self._created >= self._cap then
			return nil
		end
		obj = self._create()
		self._created += 1
	end
	self._live[obj] = true
	self._liveCount += 1
	return obj
end

function Pool.release(self: any, obj: any)
	if not self._live[obj] then
		return -- double release is ignored
	end
	self._live[obj] = nil
	self._liveCount -= 1
	self._reset(obj)
	table.insert(self._free, obj)
end

function Pool.stats(self: any)
	return { free = #self._free, live = self._liveCount, created = self._created, cap = self._cap }
end

function Pool.destroy(self: any)
	if self._destroy then
		for _, obj in self._free do
			self._destroy(obj)
		end
		for obj in self._live do
			self._destroy(obj)
		end
	end
	table.clear(self._free)
	table.clear(self._live)
	self._liveCount = 0
end

return Pool
