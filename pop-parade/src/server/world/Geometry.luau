--!strict
-- Small helpers for building anchored world geometry. Server-side world construction only.

local Geometry = {}

export type RGB = { r: number, g: number, b: number }
export type ColorLike = RGB | Color3

local function toColor3(c: ColorLike): Color3
	if typeof(c) == "Color3" then
		return c :: Color3
	end
	local t = c :: RGB
	return Color3.new(t.r, t.g, t.b)
end
Geometry.toColor3 = toColor3

function Geometry.v3(p: { x: number, y: number, z: number }): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

-- Placement {pos, yaw[, pitch]} -> CFrame. yaw 0 faces -Z.
function Geometry.cf(pos: { x: number, y: number, z: number }, yaw: number?, pitch: number?): CFrame
	return CFrame.new(pos.x, pos.y, pos.z) * CFrame.Angles(0, math.rad(yaw or 0), 0) * CFrame.Angles(math.rad(pitch or 0), 0, 0)
end

local function materialOf(name: string?): Enum.Material
	if name then
		local ok, m = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		if ok and m then
			return m
		end
	end
	return Enum.Material.SmoothPlastic
end
Geometry.materialOf = materialOf

export type PartProps = {
	material: string?,
	transparency: number?,
	reflectance: number?,
	canCollide: boolean?,
	canQuery: boolean?,
	castShadow: boolean?,
	shape: Enum.PartType?,
}

function Geometry.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: ColorLike, props: PartProps?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = toColor3(color)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local o: PartProps = props or {}
	p.Material = materialOf(o.material)
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	p.CanCollide = if o.canCollide == nil then true else o.canCollide
	p.CanQuery = if o.canQuery == nil then true else o.canQuery
	p.CastShadow = if o.castShadow == nil then true else o.castShadow
	if o.shape then
		p.Shape = o.shape
	end
	p.Parent = parent
	return p
end

-- Flat disk lying on the ground: top surface at `top`, centred at (x, z).
function Geometry.disk(parent: Instance, name: string, x: number, top: number, z: number, radius: number, thickness: number, color: ColorLike, props: PartProps?): Part
	local o: PartProps = table.clone(props or {})
	o.shape = Enum.PartType.Cylinder
	return Geometry.part(
		parent,
		name,
		Vector3.new(thickness, radius * 2, radius * 2),
		CFrame.new(x, top - thickness / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		o
	)
end

-- Vertical post/column from `bottom` up `height`.
function Geometry.column(parent: Instance, name: string, x: number, bottom: number, z: number, radius: number, height: number, color: ColorLike, props: PartProps?): Part
	local o: PartProps = table.clone(props or {})
	o.shape = Enum.PartType.Cylinder
	return Geometry.part(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(x, bottom + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		o
	)
end

function Geometry.ball(parent: Instance, name: string, center: Vector3, diameter: number, color: ColorLike, props: PartProps?): Part
	local o: PartProps = table.clone(props or {})
	o.shape = Enum.PartType.Ball
	return Geometry.part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color, o)
end

function Geometry.model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Geometry.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- World-space sign: a board with a SurfaceGui label on its front (-Z local) face.
function Geometry.sign(parent: Instance, name: string, cframe: CFrame, size: Vector2, text: string, bg: ColorLike, fg: ColorLike): Part
	local board = Geometry.part(parent, name, Vector3.new(size.X, size.Y, 0.6), cframe, bg, { castShadow = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = toColor3(fg)
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.3
	stroke.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	label.Parent = gui
	return board
end

-- Ring of `count` parts approximating a circle (rails, rims). Returns the folder.
function Geometry.ring(parent: Instance, name: string, center: Vector3, radius: number, count: number, partSize: Vector3, color: ColorLike, props: PartProps?): Folder
	local f = Geometry.folder(parent, name)
	for i = 0, count - 1 do
		local a = (i / count) * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		Geometry.part(f, name .. "_" .. i, partSize, CFrame.lookAt(pos, center), color, props)
	end
	return f
end

function Geometry.tag(inst: Instance, attrs: { [string]: any })
	for k, val in attrs do
		inst:SetAttribute(k, val)
	end
end

return Geometry
