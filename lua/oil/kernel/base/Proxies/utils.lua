local _G = require "_G"
local error = _G.error
local getmetatable = _G.getmetatable
local rawget = _G.rawget


local function callhandler(self, ...)
	local handler = rawget(self, "__exceptions")
	             or rawget(getmetatable(self), "__exceptions")
	             or error((...))
	return handler(self, ...)
end

return {
	assertresults = function (self, operation, success, except, ...)
		if not success then
			return callhandler(self, except, operation)
		end
		return except, ...
	end,
}
