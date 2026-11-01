--!strict
-- Cleanup helper: collects connections, instances, tweens, threads and functions and releases them
-- together. Every controller/panel owns one so listeners and tweens never leak on removal.

local Maid = {}
Maid.__index = Maid

export type Maid = {
	give: (self: Maid, task: any) -> any,
	clean: (self: Maid) -> (),
	count: (self: Maid) -> number,
}

function Maid.new(): Maid
	return setmetatable({ _tasks = {} :: { any } }, Maid) :: any
end

function Maid.give(self: any, item: any): any
	if item ~= nil then
		table.insert(self._tasks, item)
	end
	return item
end

-- (parameter is `item`, not `task`, so the global `task` library stays reachable)
local function release(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		if item:IsA("Tween") then
			item:Cancel()
		end
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.clean) == "function" then
			item:clean()
		end
	end
end

function Maid.clean(self: any)
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local ok, err = pcall(release :: (any) -> any, tasks[i])
		if not ok then
			warn("[PopParade] cleanup error: " .. tostring(err))
		end
	end
end

function Maid.count(self: any): number
	return #self._tasks
end

return Maid
