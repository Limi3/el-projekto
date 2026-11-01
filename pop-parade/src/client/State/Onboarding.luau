--!strict
-- One objective at a time (spec 1). Pure: returns a Strings key or nil.
-- Starts with exactly "Walk toward balloons to pop!" and never prompts a purchase.

local Selectors = require(script.Parent.Selectors)

local Onboarding = {}

export type Flags = { pops: number, upgradesBought: number, enteredStage: boolean, bossSeen: boolean, dismissedAt: number? }

function Onboarding.next(state: any, balance: any, flags: Flags): string?
	if not state then
		return nil
	end
	if flags.pops < 3 then
		return "hint.first"
	end
	if flags.upgradesBought == 0 and Selectors.firstAffordableUpgrade(state, balance) ~= nil then
		return "hint.upgrade"
	end
	if not flags.enteredStage and state.mode ~= "stage" and (state.completedStages == nil or #state.completedStages == 0) then
		return "hint.route"
	end
	local sp = Selectors.stageProgress(state)
	if sp.visible and sp.done >= sp.total and not flags.bossSeen then
		return "hint.boss"
	end
	return nil
end

return Onboarding
