local error        = error
local getmetatable = getmetatable
local rawget       = rawget

module "oil.kernel.base.Proxies.utils"

local function callhandler(self, ...)
	local handler = rawget(self, "__exceptions")
	             or rawget(getmetatable(self), "__exceptions")
	             or error((...))
	return handler(self, ...)
end

function assertresults(self, operation, success, except, ...)
	if not success then
		return callhandler(self, except, operation)
	end
	return except, ...
end
