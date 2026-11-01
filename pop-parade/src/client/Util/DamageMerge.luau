--!strict
-- Pure merge rule for floating damage numbers: rapid server-confirmed hits within `window`
-- seconds add into the newest number instead of spawning a new one (keeps the screen readable
-- and caps instance churn). Unit-tested.

local DamageMerge = {}
DamageMerge.__index = DamageMerge

export type Entry = { id: number, total: number, hits: number, lastAt: number }

function DamageMerge.new(window: number?, maxLive: number?)
	return setmetatable({ window = window or 0.35, maxLive = maxLive or 4, live = {} :: { Entry }, nextId = 0 }, DamageMerge)
end

-- Returns ("merge" | "new", entry, evicted?)
function DamageMerge.add(self: any, now: number, amount: number): (string, Entry, Entry?)
	local newest = self.live[#self.live]
	if newest and now - newest.lastAt <= self.window then
		newest.total += amount
		newest.hits += 1
		newest.lastAt = now
		return "merge", newest, nil
	end
	self.nextId += 1
	local e: Entry = { id = self.nextId, total = amount, hits = 1, lastAt = now }
	table.insert(self.live, e)
	local evicted: Entry? = nil
	if #self.live > self.maxLive then
		evicted = table.remove(self.live, 1)
	end
	return "new", e, evicted
end

function DamageMerge.expire(self: any, now: number, lifetime: number): { Entry }
	local out = {}
	local i = 1
	while i <= #self.live do
		local e = self.live[i]
		if now - e.lastAt > lifetime then
			table.insert(out, table.remove(self.live, i) :: Entry)
		else
			i += 1
		end
	end
	return out
end

return DamageMerge
