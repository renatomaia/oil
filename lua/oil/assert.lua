local _G = require "_G"
local error = _G.error
local pairs = _G.pairs
local luatype = _G.type
local require = _G.require                                                      --[[VERBOSE]] local verbose = require "oil.verbose"

local TypeCheckers = {}

local module = {
	Exception = require "oil.Exception",
	TypeCheckers = TypeCheckers,
}

function module.results(result, ...)
	if result == nil then error(..., 2) end
	return result, ...
end

function module.illegal(value, description, except)
	error(module.Exception{
		"$value is a illegal $valuekind",
		error = except or "badvalue",
		value = value,
		valuekind = description,
	}, 2)
end

function module.type(value, expected, description, except)
	local actual = luatype(value)
	if actual == expected then
		return true
	else
		local checker = TypeCheckers[expected]
		if checker then
			if checker(value) then return true end
		else
			for pattern, checker in pairs(TypeCheckers) do
				local result = expected:match(pattern)
				if result then
					result = checker(value, result)
					if result
						then return result
						else break
					end
				end
			end
		end
	end
	error(module.Exception{
		"$value is a illegal $valuekind ($expectedtype expected, got $actualtype)",
		error = except or "badvalue",
		expectedtype = expected,
		actualtype = actual,
		value = value,
		valuekind = description,
	}, 2)
end

return module
