--!strict
-- Short, non-blocking notices (errors, confirmations, checkpoints). Max 3 on screen;
-- identical messages within a short window are merged instead of stacking.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Toasts = {}
Toasts.__index = Toasts

function Toasts.new(parent: Instance)
	local holder = Kit.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 240),
		Size = UDim2.fromOffset(520, 200),
		ZIndex = Theme.zIndex.toast,
		Parent = parent,
	})
	Kit.list(Enum.FillDirection.Vertical, 6).Parent = holder
	return setmetatable({ holder = holder, live = {} :: { { text: string, label: TextLabel, at: number } }, order = 0 }, Toasts)
end

function Toasts.show(self: any, text: string, kind: string?, seconds: number?) -- kind: "info" | "good" | "bad" | "gold"
	local now = os.clock()
	for _, t in self.live do
		if t.text == text and now - t.at < 2 then
			t.at = now
			return
		end
	end
	if #self.live >= 3 then
		local oldest = table.remove(self.live, 1)
		if oldest then
			oldest.label:Destroy()
		end
	end
	self.order += 1
	local bg = if kind == "bad" then Theme.color.bad elseif kind == "good" then Theme.color.good elseif kind == "gold" then Theme.color.golden else Theme.color.shadow
	local lbl = Kit.label(text, { font = Theme.font.bold, size = 17, color = Theme.color.white, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 0), autoSize = Enum.AutomaticSize.Y, order = self.order })
	lbl.BackgroundColor3 = bg
	lbl.BackgroundTransparency = 0.08
	Kit.corner(12).Parent = lbl
	Kit.padding(8, 14).Parent = lbl
	lbl.Parent = self.holder
	local entry = { text = text, label = lbl, at = now }
	table.insert(self.live, entry)
	task.delay(seconds or 3, function()
		local i = table.find(self.live, entry)
		if i then
			table.remove(self.live, i)
		end
		if lbl.Parent then
			local tw = Kit.tween(lbl, TweenInfo.new(0.25), { TextTransparency = 1, BackgroundTransparency = 1 })
			if tw then
				tw.Completed:Once(function()
					lbl:Destroy()
				end)
			else
				lbl:Destroy()
			end
		end
	end)
end

return Toasts
