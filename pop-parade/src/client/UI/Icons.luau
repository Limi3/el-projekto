--!strict
-- Procedural icon set: simple rounded shapes built from Frames so the game ships with zero
-- uploaded images and one consistent style (no emoji). Each icon fills its holder (scale-based).
-- Replace with uploaded art later by mapping the same keys to images (docs/b/ASSET_MANIFEST.md).

local Icons = {}

local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, rot: number?, round: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.Rotation = rot or 0
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function circle(parent: Instance, x: number, y: number, d: number, color: Color3): Frame
	return rect(parent, x, y, d, d, color, 0, 0.5)
end

local function ring(parent: Instance, x: number, y: number, d: number, color: Color3, thickness: number): Frame
	local f = rect(parent, x, y, d, d, color, 0, 0.5)
	f.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = f
	return f
end

local DRAW: { [string]: (Instance, Color3) -> () } = {}

DRAW.needle = function(p, c)
	rect(p, 0.5, 0.5, 0.12, 0.9, c, 45, 0.5)
	circle(p, 0.2, 0.8, 0.3, c)
end
DRAW.speed = function(p, c)
	for i = 0, 1 do
		rect(p, 0.32 + i * 0.3, 0.36, 0.12, 0.42, c, -45, 0.5)
		rect(p, 0.32 + i * 0.3, 0.64, 0.12, 0.42, c, 45, 0.5)
	end
end
DRAW.attack = function(p, c)
	rect(p, 0.58, 0.28, 0.14, 0.5, c, 30, 0.3)
	rect(p, 0.5, 0.5, 0.42, 0.13, c, -20, 0.3)
	rect(p, 0.42, 0.72, 0.14, 0.5, c, 30, 0.3)
end
DRAW.bolt = DRAW.attack
DRAW.sound = function(p, c)
	rect(p, 0.22, 0.5, 0.2, 0.32, c, 0, 0.2)
	rect(p, 0.38, 0.5, 0.2, 0.6, c, 0, 0.2)
	ring(p, 0.55, 0.5, 0.45, c, 2.5).BackgroundTransparency = 1
	ring(p, 0.55, 0.5, 0.8, c, 2.5).BackgroundTransparency = 1
end
DRAW.inventory = function(p, c)
	rect(p, 0.5, 0.6, 0.72, 0.6, c, 0, 0.25)
	ring(p, 0.5, 0.3, 0.38, c, 3)
end
DRAW.shop = function(p, c)
	rect(p, 0.48, 0.52, 0.62, 0.62, c, 45, 0.18)
	circle(p, 0.62, 0.36, 0.16, Color3.new(1, 1, 1))
end
DRAW.more = function(p, c)
	for i = 0, 2 do
		circle(p, 0.22 + i * 0.28, 0.5, 0.2, c)
	end
end
DRAW.wheel = function(p, c)
	ring(p, 0.5, 0.5, 0.86, c, 3)
	for i = 0, 3 do
		rect(p, 0.5, 0.5, 0.08, 0.8, c, i * 45, 0.5)
	end
	circle(p, 0.5, 0.5, 0.22, c)
end
DRAW.gift = function(p, c)
	rect(p, 0.5, 0.62, 0.74, 0.56, c, 0, 0.12)
	rect(p, 0.5, 0.32, 0.86, 0.18, c, 0, 0.12)
	rect(p, 0.5, 0.55, 0.1, 0.7, Color3.new(1, 1, 1), 0, 0)
	ring(p, 0.38, 0.16, 0.22, c, 2.5)
	ring(p, 0.62, 0.16, 0.22, c, 2.5)
end
DRAW.rewards = DRAW.gift
DRAW.settings = function(p, c)
	for i = 0, 5 do
		rect(p, 0.5, 0.5, 0.18, 0.92, c, i * 30, 0.3)
	end
	circle(p, 0.5, 0.5, 0.66, c)
	circle(p, 0.5, 0.5, 0.28, Color3.new(1, 1, 1))
end
DRAW.journal = function(p, c)
	rect(p, 0.5, 0.5, 0.7, 0.86, c, 0, 0.12)
	-- spine + label line contrast with the cover (also when the cover itself is white)
	local detail = if c.R + c.G + c.B > 2.7 then Color3.fromRGB(150, 120, 60) else Color3.new(1, 1, 1)
	rect(p, 0.32, 0.5, 0.06, 0.86, detail, 0, 0)
	rect(p, 0.6, 0.36, 0.3, 0.08, detail, 0, 0.5)
end
DRAW.heart = function(p, c)
	circle(p, 0.34, 0.38, 0.42, c)
	circle(p, 0.66, 0.38, 0.42, c)
	rect(p, 0.5, 0.6, 0.48, 0.48, c, 45, 0.12)
end
DRAW.life = function(p, c)
	DRAW.heart(p, c)
	rect(p, 0.5, 0.5, 0.36, 0.1, Color3.new(1, 1, 1), 0, 0.5)
	rect(p, 0.5, 0.5, 0.1, 0.36, Color3.new(1, 1, 1), 0, 0.5)
end
DRAW.coin = function(p, c)
	circle(p, 0.5, 0.5, 0.9, c)
	ring(p, 0.5, 0.5, 0.62, Color3.new(1, 1, 1), 2)
	rect(p, 0.5, 0.5, 0.12, 0.36, Color3.new(1, 1, 1), 0, 0.5)
end
DRAW.star = function(p, c)
	rect(p, 0.5, 0.52, 0.56, 0.56, c, 0, 0.1)
	rect(p, 0.5, 0.52, 0.56, 0.56, c, 45, 0.1)
end
DRAW.xp = DRAW.star
DRAW.crown = function(p, c)
	rect(p, 0.5, 0.7, 0.8, 0.3, c, 0, 0.15)
	for i = 0, 2 do
		rect(p, 0.22 + i * 0.28, 0.45, 0.2, 0.36, c, 45, 0.2)
	end
end
DRAW.trail = function(p, c)
	for i = 0, 2 do
		rect(p, 0.45 + i * 0.05, 0.28 + i * 0.22, 0.8 - i * 0.18, 0.12, c, 0, 0.5)
	end
end
DRAW.rocket = function(p, c)
	rect(p, 0.55, 0.45, 0.3, 0.6, c, 45, 0.5)
	circle(p, 0.25, 0.75, 0.22, c)
end
DRAW.wings = function(p, c)
	rect(p, 0.3, 0.45, 0.36, 0.6, c, -25, 0.5)
	rect(p, 0.7, 0.45, 0.36, 0.6, c, 25, 0.5)
end
DRAW.confetti = function(p, c)
	rect(p, 0.25, 0.3, 0.16, 0.24, c, 20, 0.2)
	rect(p, 0.7, 0.25, 0.16, 0.24, c, -30, 0.2)
	rect(p, 0.45, 0.65, 0.16, 0.24, c, 50, 0.2)
	circle(p, 0.75, 0.7, 0.16, c)
end
DRAW.shoe = function(p, c)
	rect(p, 0.45, 0.6, 0.7, 0.34, c, 0, 0.3)
	rect(p, 0.3, 0.38, 0.32, 0.36, c, 0, 0.2)
end
DRAW.goggles = function(p, c)
	ring(p, 0.3, 0.5, 0.38, c, 3)
	ring(p, 0.7, 0.5, 0.38, c, 3)
	rect(p, 0.5, 0.5, 0.14, 0.08, c, 0, 0)
end
DRAW.glove = function(p, c)
	rect(p, 0.5, 0.62, 0.58, 0.56, c, 0, 0.3)
	for i = 0, 2 do
		rect(p, 0.32 + i * 0.18, 0.3, 0.14, 0.34, c, 0, 0.5)
	end
end
DRAW.skip = function(p, c)
	rect(p, 0.3, 0.38, 0.1, 0.36, c, -45, 0.5)
	rect(p, 0.3, 0.62, 0.1, 0.36, c, 45, 0.5)
	rect(p, 0.55, 0.38, 0.1, 0.36, c, -45, 0.5)
	rect(p, 0.55, 0.62, 0.1, 0.36, c, 45, 0.5)
	rect(p, 0.8, 0.5, 0.1, 0.62, c, 0, 0.5)
end
DRAW.hits = function(p, c)
	for i = 0, 2 do
		circle(p, 0.2 + i * 0.3, 0.42 + (i % 2) * 0.16, 0.3, c)
	end
end
DRAW.balloon = function(p, c)
	circle(p, 0.5, 0.4, 0.66, c)
	rect(p, 0.5, 0.8, 0.14, 0.14, c, 45, 0.1)
end
DRAW.popped = function(p, c)
	for i = 0, 5 do
		rect(p, 0.5, 0.5, 0.1, 0.42, c, i * 60, 0.5).Position = UDim2.fromScale(0.5 + math.sin(math.rad(i * 60)) * 0.24, 0.5 - math.cos(math.rad(i * 60)) * 0.24)
	end
	circle(p, 0.5, 0.5, 0.2, c)
end
DRAW.lock = function(p, c)
	rect(p, 0.5, 0.64, 0.66, 0.5, c, 0, 0.2)
	ring(p, 0.5, 0.36, 0.42, c, 3)
end
DRAW.check = function(p, c)
	rect(p, 0.36, 0.6, 0.12, 0.34, c, -45, 0.5)
	rect(p, 0.6, 0.48, 0.12, 0.6, c, 40, 0.5)
end
DRAW.question = function(p, c)
	ring(p, 0.5, 0.36, 0.44, c, 3)
	rect(p, 0.5, 0.64, 0.1, 0.18, c, 0, 0.5)
	circle(p, 0.5, 0.86, 0.12, c)
end
DRAW.Needle = DRAW.needle
DRAW.Speed = DRAW.speed
DRAW.Attack = DRAW.attack
DRAW.Hits = DRAW.hits
DRAW.Life = DRAW.life
DRAW.Sound = DRAW.sound
DRAW.Inventory = DRAW.inventory
DRAW.Shop = DRAW.shop
DRAW.More = DRAW.more
DRAW.Wheel = DRAW.wheel
DRAW.Rewards = DRAW.gift
DRAW.Journal = DRAW.journal
DRAW.Settings = DRAW.settings

function Icons.draw(key: string, parent: Instance, color: Color3)
	local fn = DRAW[key] or DRAW.question
	fn(parent, color)
end

-- Returns a function suitable for Kit.button({icon = Icons.fn("needle")})
function Icons.fn(key: string): (Instance, Color3) -> ()
	return function(parent: Instance, color: Color3)
		Icons.draw(key, parent, color)
	end
end

function Icons.has(key: string): boolean
	return DRAW[key] ~= nil
end

return Icons
