local _G = require "_G"
local rawget = _G.rawget

local utils = require "oil.kernel.base.Proxies.utils"
local TimeoutKey = utils.keys.timeout

return function(invoker)
	return function(self, ...)
		return invoker(self, ...):getreply(self[TimeoutKey])
	end
end
