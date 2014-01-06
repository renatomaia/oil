local oil = require "oil"

oil.main(function()
	local Invoker = {}
	function Invoker:invoke(object, method, ...)
		object[method](object, ...)
	end
	
	orb = oil.init{flavor="cooperative;ludo"}
	oil.writeto("ref.ludo", orb:newservant(Invoker))
end)