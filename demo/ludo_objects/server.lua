require "oil"

oil.main(function()
	local broker = oil.init{flavor="cooperative;ludo"}
	
	local Invoker = {}
	function Invoker:invoke(object, method, ...)
		object[method](object, ...)
	end
	
	oil.writeto("ref.ludo",
		broker:tostring(
			broker:newservant(Invoker)))
	
	broker:run()
end)