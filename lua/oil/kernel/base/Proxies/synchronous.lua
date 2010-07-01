local utils = require "oil.kernel.base.Proxies.utils"
local assert = utils.assertresults

return function(invoker, operation)
	return function(self, ...)
		return assert(self, operation, invoker(self, ...):results(self.__timeout))
	end
end
