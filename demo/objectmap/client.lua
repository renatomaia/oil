local oil = require "oil"

oil.main(function()
	local orb = oil.init()
	
	helloWorld   = orb:newproxy("corbaloc::localhost:2809/World")
	helloJohnDoe = orb:newproxy("corbaloc::localhost:2809/John Doe")
	
	print(helloWorld:say())
	print(helloJohnDoe:say())
	print(helloWorld:say())
	print(helloJohnDoe:say())
	print(helloWorld:say())
	print(helloJohnDoe:say())
	
	orb:shutdown()
end)
