--!strict
-- Pure formatting helpers (numbers, durations). Locale-neutral; text templates live in Strings.

local Format = {}

-- 1234 -> "1,234"; 12345678 -> "12.3M"
function Format.number(n: number): string
	if n ~= n then
		return "?"
	end
	local neg = n < 0
	n = math.abs(math.floor(n + 0.5))
	local s: string
	if n >= 1e9 then
		s = string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		s = string.format("%.1fM", n / 1e6)
	elseif n >= 1e5 then
		s = string.format("%.0fK", n / 1e3)
	else
		s = tostring(n)
		local formatted = s
		while true do
			local k: number
			formatted, k = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
			if k == 0 then
				break
			end
		end
		s = formatted
	end
	s = string.gsub(s, "%.0([KMB])$", "%1")
	return if neg then "-" .. s else s
end

-- Compact number for floating damage: 7, 1.2K, 34K, 1.5M
function Format.compact(n: number): string
	n = math.floor(n + 0.5)
	if n < 1000 then
		return tostring(n)
	elseif n < 10000 then
		return (string.gsub(string.format("%.1fK", n / 1000), "%.0K", "K"))
	elseif n < 1e6 then
		return string.format("%dK", math.floor(n / 1000))
	end
	return (string.gsub(string.format("%.1fM", n / 1e6), "%.0M", "M"))
end

-- seconds -> "1:05", "12:00", "3:04:05"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- Probability (0..1) -> "70%", "0.9%", "0.1%"; never rounds a non-zero chance to "0%".
function Format.percent(p: number): string
	local pct = p * 100
	if pct >= 10 or math.abs(pct - math.floor(pct + 0.5)) < 1e-9 then
		return string.format("%d%%", math.floor(pct + 0.5))
	elseif pct >= 1 then
		return (string.gsub(string.format("%.1f%%", pct), "%.0%%", "%%"))
	elseif pct >= 0.1 then
		return (string.gsub(string.format("%.2f%%", pct), "0%%$", "%%"))
	elseif pct > 0 then
		return string.format("%.3g%%", pct)
	end
	return "0%"
end

return Format
