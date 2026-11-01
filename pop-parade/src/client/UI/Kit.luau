--!strict
-- Minimal UI kit: declarative-ish Instance creation + the shared rounded components.
-- Every interactive element: >= 48 px touch target, gamepad Selectable with a visible focus ring,
-- hover/press feedback that respects Reduced Motion, and text from the Strings table.

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)

local Kit = {}

-- Global presentation flags (set by SettingsController from the server-confirmed settings)
Kit.reducedMotion = false

export type Props = { [string]: any }

-- new("Frame", {Size=..., [Kit.Children]={...}, [Kit.Event.Activated]=fn})
Kit.Children = "__children"
Kit.OnActivated = "__activated"

function Kit.new(className: string, props: Props?, children: { Instance }?): any
	local inst = Instance.new(className)
	local p: Props = props or {}
	local parent = p.Parent
	for k, v in p do
		if k == "Parent" or k == Kit.Children or k == Kit.OnActivated then
			continue
		end
		(inst :: any)[k] = v
	end
	for _, ch in children or p[Kit.Children] or {} do
		ch.Parent = inst
	end
	if p[Kit.OnActivated] then
		(inst :: any).Activated:Connect(p[Kit.OnActivated])
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.size.corner) })
end

function Kit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or Theme.color.ink,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.textStroke(thickness: number?): UIStroke
	return Kit.new("UIStroke", { Color = Theme.color.shadow, Thickness = thickness or 2, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

function Kit.padding(all: number, x: number?): UIPadding
	return Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, x or all),
		PaddingRight = UDim.new(0, x or all),
	})
end

function Kit.list(dir: Enum.FillDirection?, gap: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or Theme.size.gap),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Kit.label(text: string, opts: Props?): TextLabel
	local o: Props = opts or {}
	local lbl = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontFace = o.font or Theme.font.body,
		TextSize = o.size or Theme.size.text,
		TextColor3 = o.color or Theme.color.ink,
		TextWrapped = o.wrap ~= false,
		TextXAlignment = o.align or Enum.TextXAlignment.Left,
		TextYAlignment = o.valign or Enum.TextYAlignment.Center,
		Size = o.frameSize or UDim2.new(1, 0, 0, (o.size or Theme.size.text) + 8),
		AutomaticSize = o.autoSize or Enum.AutomaticSize.None,
		LayoutOrder = o.order or 0,
		RichText = o.rich == true,
		Name = o.name or "Label",
	})
	if o.stroke then
		Kit.textStroke(o.strokeThickness).Parent = lbl
	end
	return lbl
end

function Kit.tween(inst: Instance, info: TweenInfo, goal: { [string]: any }): Tween?
	if Kit.reducedMotion then
		for k, v in goal do
			(inst :: any)[k] = v
		end
		return nil
	end
	local tw = TweenService:Create(inst, info, goal)
	tw:Play()
	return tw
end

local FOCUS_RING: ImageLabel? = nil
local function focusRing(): ImageLabel
	if not FOCUS_RING then
		local ring = Kit.new("ImageLabel", {
			Name = "PopParadeFocus",
			BackgroundTransparency = 1,
			Image = "",
			Size = UDim2.new(1, 8, 1, 8),
			Position = UDim2.new(0, -4, 0, -4),
		})
		Kit.corner(Theme.size.corner + 4).Parent = ring
		Kit.new("UIStroke", { Color = Theme.color.white, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }).Parent = ring
		Kit.new("UIStroke", { Color = Theme.color.secondary, Thickness = 5, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Name = "Outer" }).Parent = ring
		FOCUS_RING = ring
	end
	return FOCUS_RING :: ImageLabel
end

export type ButtonOpts = {
	text: string?,
	color: Color3?,
	textColor: Color3?,
	size: UDim2?,
	icon: ((parent: Instance, color: Color3) -> ())?,
	iconColor: Color3?,
	order: number?,
	onClick: (() -> ())?,
	tooltip: string?,
	style: ("solid" | "soft" | "ghost")?,
	textSize: number?,
	name: string?,
}

-- Rounded button with press bounce, disabled state, focus ring and optional icon.
function Kit.button(opts: ButtonOpts): TextButton
	local color = opts.color or Theme.color.primary
	local style = opts.style or "solid"
	local btn = Kit.new("TextButton", {
		Name = opts.name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = if style == "solid" then color elseif style == "soft" then Theme.color.paperDim else Theme.color.white,
		BackgroundTransparency = if style == "ghost" then 1 else 0,
		Size = opts.size or UDim2.new(1, 0, 0, Theme.size.touchMin + 4),
		Text = "",
		LayoutOrder = opts.order or 0,
		Selectable = true,
		SelectionImageObject = focusRing(),
	})
	Kit.corner().Parent = btn
	if style ~= "ghost" then
		Kit.stroke(if style == "solid" then Theme.color.white else color, 2, if style == "solid" then 0.4 else 0).Parent = btn
	end
	local content = Kit.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn })
	Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = content
	if opts.icon then
		local holder = Kit.new("Frame", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), LayoutOrder = 1, Parent = content })
		opts.icon(holder, opts.iconColor or (if style == "solid" then Theme.color.white else color))
	end
	if opts.text then
		local lbl = Kit.label(opts.text, {
			font = Theme.font.display,
			size = opts.textSize or Theme.size.text,
			color = opts.textColor or (if style == "solid" then Theme.color.white else Theme.color.ink),
			align = Enum.TextXAlignment.Center,
			frameSize = UDim2.new(0, 0, 1, 0),
			autoSize = Enum.AutomaticSize.X,
			wrap = false,
			order = 2,
			stroke = style == "solid",
			strokeThickness = 1.5,
			name = "Text",
		})
		lbl.Parent = content
	end
	local scale = Kit.new("UIScale", { Parent = btn })
	btn.MouseButton1Down:Connect(function()
		if btn:GetAttribute("Disabled") then
			return
		end
		Kit.tween(scale, TweenInfo.new(0.07), { Scale = 0.94 })
	end)
	local function release()
		Kit.tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 })
	end
	btn.MouseButton1Up:Connect(release)
	btn.MouseLeave:Connect(release)
	if opts.onClick then
		local onClick = opts.onClick
		btn.Activated:Connect(function()
			if not btn:GetAttribute("Disabled") then
				onClick()
			end
		end)
	end
	btn:SetAttribute("BaseColor", color)
	return btn
end

function Kit.setButtonText(btn: TextButton, text: string)
	local lbl = btn:FindFirstChild("Content") and (btn :: any).Content:FindFirstChild("Text")
	if lbl then
		lbl.Text = text
	end
end

-- Disabled buttons stay visible (and selectable for focus/tooltips) but read clearly as unavailable.
function Kit.setEnabled(btn: TextButton, enabled: boolean)
	btn:SetAttribute("Disabled", not enabled)
	local base = btn:GetAttribute("BaseColor")
	if btn.BackgroundTransparency < 1 and typeof(base) == "Color3" then
		btn.BackgroundColor3 = if enabled then base else Theme.color.disabled
	end
	btn.AutoButtonColor = false
	btn.Active = enabled
end

function Kit.bar(fill: Color3, height: number?): (Frame, Frame)
	local track = Kit.new("Frame", { Name = "Track", BackgroundColor3 = Theme.color.shadow, BackgroundTransparency = 0.45, Size = UDim2.new(1, 0, 0, height or 14) })
	Kit.corner(99).Parent = track
	local fillFrame = Kit.new("Frame", { Name = "Fill", BackgroundColor3 = fill, Size = UDim2.fromScale(0, 1), Parent = track })
	Kit.corner(99).Parent = fillFrame
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.82, 0.82, 0.82)),
		Rotation = 90,
		Parent = fillFrame,
	})
	return track, fillFrame
end

function Kit.setBar(fillFrame: Frame, fraction: number, animate: boolean?)
	local goal = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	if animate then
		Kit.tween(fillFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = goal })
	else
		fillFrame.Size = goal
	end
end

function Kit.pill(color: Color3, width: number?): Frame
	local f = Kit.new("Frame", { BackgroundColor3 = Theme.color.white, BackgroundTransparency = 0.05, Size = UDim2.fromOffset(width or 150, 40), AutomaticSize = if width then Enum.AutomaticSize.None else Enum.AutomaticSize.X })
	Kit.corner(99).Parent = f
	Kit.stroke(color, 3).Parent = f
	Kit.padding(4, 12).Parent = f
	Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = f
	return f
end

-- On/off toggle row with a text label; value shown in words as well as colour.
function Kit.toggle(text: string, value: boolean, onChange: (boolean) -> (), order: number?): (Frame, (boolean) -> ())
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Theme.size.touchMin + 4), LayoutOrder = order or 0 })
	local lbl = Kit.label(text, { frameSize = UDim2.new(1, -120, 1, 0), size = Theme.size.text, font = Theme.font.bold })
	lbl.Parent = row
	local current = value
	local btn: TextButton
	local function render()
		Kit.setButtonText(btn, if current then "On" else "Off")
		btn.BackgroundColor3 = if current then Theme.color.good else Theme.color.disabled
		btn:SetAttribute("BaseColor", btn.BackgroundColor3)
	end
	btn = Kit.button({
		text = if value then "On" else "Off",
		color = if value then Theme.color.good else Theme.color.disabled,
		size = UDim2.new(0, 108, 1, -4),
		onClick = function()
			current = not current
			render()
			onChange(current)
		end,
	})
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, 0, 0.5, 0)
	btn.Parent = row
	return row, function(v: boolean)
		current = v
		render()
	end
end

-- Slider with big step buttons (touch/gamepad friendly) and drag on the track.
function Kit.slider(text: string, min: number, max: number, step: number, value: number, format: (number) -> string, onCommit: (number) -> (), order: number?): (Frame, (number, number?, number?) -> ())
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 84), LayoutOrder = order or 0 })
	local title = Kit.label(text, { frameSize = UDim2.new(1, 0, 0, 26), font = Theme.font.bold })
	title.Parent = row
	local cur, lo, hi = value, min, max
	local valueLabel = Kit.label("", { frameSize = UDim2.new(0, 110, 0, 26), align = Enum.TextXAlignment.Right, font = Theme.font.bold })
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, 0, 0, 0)
	valueLabel.Parent = row
	local trackHolder = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, -124, 0, Theme.size.touchMin), Position = UDim2.new(0, 62, 0, 32), Selectable = false, Parent = row })
	local track, fill = Kit.bar(Theme.color.secondary, 12)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.fromScale(0, 0.5)
	track.Parent = trackHolder
	local function render()
		valueLabel.Text = format(cur)
		Kit.setBar(fill, if hi > lo then (cur - lo) / (hi - lo) else 1, false)
	end
	local function set(v: number, commit: boolean)
		local snapped = math.clamp(lo + math.floor((v - lo) / step + 0.5) * step, lo, hi)
		if snapped ~= cur then
			cur = snapped
			render()
			if commit then
				onCommit(cur)
			end
		end
	end
	local minus = Kit.button({ text = "−", size = UDim2.fromOffset(52, Theme.size.touchMin), color = Theme.color.secondary, textSize = 26, onClick = function()
		set(cur - step, true)
	end })
	minus.Position = UDim2.new(0, 0, 0, 32)
	minus.Parent = row
	local plus = Kit.button({ text = "+", size = UDim2.fromOffset(52, Theme.size.touchMin), color = Theme.color.secondary, textSize = 26, onClick = function()
		set(cur + step, true)
	end })
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.new(1, 0, 0, 32)
	plus.Parent = row
	local dragging = false
	local function fromX(x: number)
		local abs = track.AbsolutePosition.X
		local w = math.max(1, track.AbsoluteSize.X)
		set(lo + (hi - lo) * math.clamp((x - abs) / w, 0, 1), false)
	end
	trackHolder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	trackHolder.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	trackHolder.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			onCommit(cur)
		end
	end)
	render()
	return row, function(v: number, newMin: number?, newMax: number?)
		lo = newMin or lo
		hi = newMax or hi
		cur = math.clamp(v, lo, hi)
		render()
	end
end

-- Hover/focus tooltip for icon buttons (also readable on touch via long-press label below icon).
function Kit.attachTooltip(target: GuiObject, text: string, tooltipLayer: Instance)
	local tip: TextLabel? = nil
	local function show()
		if tip then
			return
		end
		local t = Kit.label(text, { size = Theme.size.textSmall, color = Theme.color.white, autoSize = Enum.AutomaticSize.XY, frameSize = UDim2.fromOffset(0, 0), wrap = false })
		t.BackgroundTransparency = 0.1
		t.BackgroundColor3 = Theme.color.shadow
		Kit.corner(8).Parent = t
		Kit.padding(6, 10).Parent = t
		t.ZIndex = 100
		local p = target.AbsolutePosition + Vector2.new(target.AbsoluteSize.X + 10, target.AbsoluteSize.Y / 2 - 14)
		t.Position = UDim2.fromOffset(p.X, p.Y)
		t.Parent = tooltipLayer
		tip = t
	end
	local function hide()
		if tip then
			tip:Destroy()
			tip = nil
		end
	end
	target.MouseEnter:Connect(show)
	target.MouseLeave:Connect(hide)
	target.SelectionGained:Connect(show)
	target.SelectionLost:Connect(hide)
	target.AncestryChanged:Connect(function(_, parent)
		if not parent then
			hide()
		end
	end)
end

function Kit.focus(obj: GuiObject?)
	if obj and GuiService.GuiNavigationEnabled ~= false then
		GuiService.SelectedObject = obj
	end
end

return Kit
