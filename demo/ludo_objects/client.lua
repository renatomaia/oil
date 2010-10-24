require "oil"

oil.main(function()
	local orb = oil.init{
		flavor = "cooperative;ludo",
		localrefs = "proxy", -- disable local reference resolution
	}
	
	oil.newthread(orb.run, orb)
	
	local Hello = {}
	function Hello:say(who)
		print(string.format("Hello, %s!", tostring(who)))
	end
	
	local Invoker = orb:newproxy(oil.readfrom("ref.ludo"))
	local proxy = orb:newproxy(
	              	orb:tostring(
	              		orb:newservant(Hello)))
	
	Invoker:invoke(Hello, "say", "there") -- message appear remotely
	Invoker:invoke(proxy, "say", "here") -- message appear locally
	
	orb:shutdown()
end)