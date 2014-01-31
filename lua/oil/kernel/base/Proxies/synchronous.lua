local _G = require "_G"
local rawget = _G.rawget

local utils = require "oil.kernel.base.Proxies.utils"
local assert = utils.assertresults
local TimeoutKey = utils.TimeoutKey

return function(invoker, operation)
	return function(self, ...)
		local timeout = self[TimeoutKey]
		return assert(self, operation, invoker(self, ...):getreply(timeout))
	end
end
