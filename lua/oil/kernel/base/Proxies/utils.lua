local _G = require "_G"
local error = _G.error
local getmetatable = _G.getmetatable
local rawget = _G.rawget


local ExHandlerKey = {"Exception Handler Key"}
local TimeoutKey = {"Invocation Timeout Key"}

local function callhandler(self, ...)
	local handler = self[ExHandlerKey]
	             or error((...))
	return handler(self, ...)
end

return {
	ExHandlerKey = ExHandlerKey,
	TimeoutKey = TimeoutKey,
	assertresults = function (self, operation, success, ...)
		if not success then
			return callhandler(self, ..., operation)
		end
		return ...
	end,
}
