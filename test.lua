local all_tests = {
	"test/identity.lua", -- Empty account
}

--- Constructs a table of expected test results by assuming all accounts should fail,
--- except for those provided via `exceptions`.
--- @param exceptions string[]
--- @return table<string, boolean>
local function verify(exceptions)
	local result = {}
	for _, test in ipairs(all_tests) do
		result[test] = false
	end
	for _, test in ipairs(exceptions) do
		result[test] = true
	end
	return result
end

--- Use `verify` to implicitly assume `all_tests` should fail.
--- If this behavior is undesired, use a table mapping the test account paths to boolean values.
--- For example:
--[[
	["scripts/test.lua"] = {
		["test/success.lua"] = true,
		["test/failure.lua"] = false
	}
]]
return {
	["scripts/nicotine_dependence_with_withdrawal.lua"] = verify {}
}
