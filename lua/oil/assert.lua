local _G = require "_G"
local error = _G.error
local pairs = _G.pairs
local luatype = _G.type
local require = _G.require                                                      --[[VERBOSE]] local verbose = require "oil.verbose"

module(...)

Exception = require "oil.Exception"

function results(result, ...)
	if result == nil then error(..., 2) end
	return result, ...
end

function illegal(value, description, except)
	error(Exception{ except or "badvalue",
		message = "illegal $valuekind",
		value = value,
		valuekind = description,
	}, 2)
end

TypeCheckers = {}

function type(value, expected, description, except)
	local actual = luatype(value)
	if actual == expected then
		return true
	else
		local checker = TypeCheckers[expected]
		if checker then
			return checker(value)
		else
			for pattern, checker in pairs(TypeCheckers) do
				local result = expected:match(pattern)
				if result then
					checker, result = checker(value, result)
					if checker then return true end
					expected = result or expected
					break
				end
			end
		end
	end
	error(Exception{ except or "badvalue",
		message = "illegal $valuekind ($expectedtype expected, got $actualtype)",
		expectedtype = expected,
		actualtype   = actual,
		value        = value,
		valuekind    = description,
	}, 2)
end
