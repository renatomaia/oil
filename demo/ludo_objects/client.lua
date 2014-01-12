local oil = require "oil"

oil.main(function()
	orb = oil.init{
		flavor = "cooperative;ludo;ludo.byref",
		localrefs = "proxy", -- disable local reference resolution
	}
	
	local Hello = {}
	function Hello:say(who)
		print(string.format("Hello, %s!", tostring(who)))
	end
	Invoker = orb:newproxy(oil.readfrom("ref.ludo"))
	proxy = orb:newproxy(tostring(orb:newservant(Hello)))
	
	Invoker:invoke(Hello, "say", "there") -- message appear remotely
	Invoker:invoke(proxy, "say", "here") -- message appear locally
	
	orb:shutdown()
end)