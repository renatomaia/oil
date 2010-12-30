local utils = require "oil.kernel.base.Proxies.utils"                           --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = utils.assertresults

local function ready(self)
	local result, except = self:getreply(0)
	return result or except.error ~= "timeout"
end
local function results(self, timeout)
	return self:getreply(timeout)
end
local function evaluate(self, timeout)
	return assert(self.proxy, self.opinfo, self:getreply(timeout))
end

return function(invoker, operation)
	return function(self, ...)
		local request = invoker(self, ...)
		request.proxy = self
		request.opinfo = operation
		request.ready = ready
		request.results = results
		request.evaluate = evaluate
		return request
	end
end
