local _G = require "_G"
local rawget = _G.rawget

return function(invoker)
	return function(self, ...)
		return invoker(self, ...):results(rawget(self, "__timeout"))
	end
end
