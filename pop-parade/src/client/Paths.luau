--!strict
-- Where the client finds shared modules. Kept in one place so A's final Rojo layout only
-- requires changing this file (requested layout: docs/b/CONTRACT_REQUESTS.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Paths = {}

function Paths.content(): any
	return require(ReplicatedStorage:WaitForChild("PopParade"):WaitForChild("Content") :: ModuleScript) :: any
end

-- A's shared balance accessor (A-owned). Expected to expose the Selectors.Balance interface.
-- Returns nil if A hasn't shipped it: the UI then shows "unavailable", never invented numbers.
function Paths.balance(): any?
	local root = ReplicatedStorage:FindFirstChild("PopParade")
	local mod = root and (root:FindFirstChild("BalanceView") or root:FindFirstChild("Balance"))
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then
			return result
		end
		warn("[PopParade] balance module failed to load: " .. tostring(result))
	end
	return nil
end

-- Test-only preview hook. Only active inside Studio AND only when tests/b is mapped
-- (preview-b.project.json). A production place never contains PopParadeTestB.
function Paths.previewMock(): Instance?
	if not RunService:IsStudio() then
		return nil
	end
	local test = ReplicatedStorage:FindFirstChild("PopParadeTestB")
	return test and test:FindFirstChild("Mock")
end

return Paths
