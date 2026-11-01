-- Entry point for B's unit tests. CLI: see tests/b/README.md
local TestKit = require(script.Parent.TestKit)

local suites = {}
local function add(mod)
	for name, cases in require(mod) do
		suites[name] = cases
	end
end

add(script.Parent["Layouts.spec"])
add(script.Parent["Secrets.spec"])
add(script.Parent["Client.spec"])
add(script.Parent["Feel.spec"])
add(script.Parent["Strings.spec"])

local passed, failed = TestKit.run(suites)
if failed > 0 then
	error(string.format("%d test(s) failed", failed))
end
return passed
