local utils = require "oil.kernel.base.Proxies.utils"                           --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = utils.assertresults

local function evaluate(self)
	return assert(self.proxy, self.operation, self:results())
end

return function(invoker, operation)
	return function(self, ...)
		local request = invoker(self, ...)
		request.proxy = self
		request.operation = operation
		request.evaluate = evaluate
		return request
	end
end
