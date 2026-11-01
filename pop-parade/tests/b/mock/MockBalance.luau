--!strict
-- TEST-ONLY stand-in for A's shared balance accessor (src/shared/balance is A-owned).
-- Numbers are the spec's seed values with an illustrative curve, ONLY so screens can be exercised.
-- They are not B's balance proposal and must never ship.

local MockBalance = {}

local MAX = { Needle = 50, Speed = 15, Attack = 30, Hits = 2, Life = 2 }

function MockBalance.upgradeMaxLevel(id: string): number?
	return MAX[id]
end

function MockBalance.upgradeCost(id: string, level: number): number?
	local max = MAX[id]
	if not max or level >= max then
		return nil
	end
	local base = ({ Needle = 10, Speed = 25, Attack = 20, Hits = 500, Life = 400 } :: any)[id]
	return math.floor(base * (1.35 ^ level) + 0.5)
end

function MockBalance.upgradeValueText(id: string, level: number): string?
	if id == "Needle" then
		return tostring(5 + level * 3) .. " dmg"
	elseif id == "Speed" then
		return tostring(16 + level) .. " speed"
	elseif id == "Attack" then
		return string.format("%.2f/s", 2 + level * 0.06)
	elseif id == "Hits" then
		return tostring(1 + level) .. " targets"
	elseif id == "Life" then
		return tostring(3 + level) .. " hearts"
	end
	return nil
end

function MockBalance.speedRange(state: any): { min: number, max: number }?
	local max = state and state.stats and state.stats.moveSpeedMax
	if type(max) ~= "number" then
		return nil
	end
	return { min = 12, max = max }
end

return MockBalance
