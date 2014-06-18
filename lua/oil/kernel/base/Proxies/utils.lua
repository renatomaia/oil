local _G = require "_G"
local error = _G.error
local getmetatable = _G.getmetatable
local rawget = _G.rawget


local ExHandlerKey = {"Exception Handler Key"}

local function callhandler(self, ...)
	local handler = self[ExHandlerKey]
	             or error((...))
	return handler(self, ...)
end

return {
	keys = {
		excatch = ExHandlerKey,
		timeout = {"Invocation Timeout Key"},
		security = {"Security Requirement Key"},
		ssl = {"SSL Options Key"},
	},
	assertresults = function (self, operation, success, ...)
		if not success then
			return callhandler(self, ..., operation)
		end
		return ...
	end,
}
