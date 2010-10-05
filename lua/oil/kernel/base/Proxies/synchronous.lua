local _G = require "_G"
local rawget = _G.rawget

local utils = require "oil.kernel.base.Proxies.utils"
local assert = utils.assertresults

return function(invoker, operation)
	return function(self, ...)
		local timeout = rawget(self, "__timeout")
		return assert(self, operation, invoker(self, ...):results(timeout))
	end
end
