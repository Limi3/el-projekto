-- Locates B modules both in the CLI bundle (fake tree) and in Studio (real services).
local Env = {}

local g: any = (getfenv :: any)().game

if g == nil then
	local root = script.Parent.Parent.Parent -- Root of the fake tree
	Env.Content = root.Content
	Env.World = root.World
	Env.Client = root.Client
	Env.inStudio = false
else
	local RS = g:GetService("ReplicatedStorage")
	local SSS = g:GetService("ServerScriptService")
	Env.Content = RS:WaitForChild("PopParade"):WaitForChild("Content")
	Env.World = SSS:WaitForChild("PopParadeWorld")
	Env.Client = nil -- client modules live under StarterPlayerScripts; client specs run in the CLI only
	Env.inStudio = true
end

return Env
