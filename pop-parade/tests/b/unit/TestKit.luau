-- Minimal test kit for B's pure modules (runs under plain `luau` via tests/b/tools/bundle.py,
-- and inside Studio via tests/b/preview/RunUnitTests.server.luau).

local TestKit = {}

export type T = {
	ok: (cond: any, msg: string?) -> (),
	eq: (a: any, b: any, msg: string?) -> (),
	near: (a: number, b: number, eps: number, msg: string?) -> (),
}

function TestKit.run(suites: { [string]: { [string]: (t: T) -> () } }, print_: ((string) -> ())?): (number, number)
	local out = print_ or print
	local passed, failed = 0, 0
	local names = {}
	for name in suites do
		table.insert(names, name)
	end
	table.sort(names)
	for _, suiteName in names do
		local cases = suites[suiteName]
		local caseNames = {}
		for name in cases do
			table.insert(caseNames, name)
		end
		table.sort(caseNames)
		for _, caseName in caseNames do
			local failures = {}
			local t: T = {
				ok = function(cond, msg)
					if not cond then
						table.insert(failures, msg or "expected truthy")
					end
				end,
				eq = function(a, b, msg)
					if a ~= b then
						table.insert(failures, string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)))
					end
				end,
				near = function(a, b, eps, msg)
					if math.abs(a - b) > eps then
						table.insert(failures, string.format("%s: expected %s ± %s, got %s", msg or "near", tostring(b), tostring(eps), tostring(a)))
					end
				end,
			}
			local okCall, err = pcall(cases[caseName], t)
			if not okCall then
				table.insert(failures, "error: " .. tostring(err))
			end
			if #failures == 0 then
				passed += 1
				out(string.format("PASS  %s :: %s", suiteName, caseName))
			else
				failed += 1
				out(string.format("FAIL  %s :: %s", suiteName, caseName))
				for i = 1, math.min(#failures, 12) do
					out("        - " .. failures[i])
				end
				if #failures > 12 then
					out(string.format("        ... and %d more", #failures - 12))
				end
			end
		end
	end
	out(string.format("\n%d passed, %d failed", passed, failed))
	return passed, failed
end

return TestKit
