local oil = require "oil"
local giop = require "oil.corba.giop"

oil.main(function()
	local orb = oil.init()
	
	orb:loadidlfile("hello.idl")

	local hello = orb:newproxy("corbaloc::/MyHello", nil, "Hello")

	local secs = 1
	local dots = 3
	repeat
		local ok, result = pcall(hello._non_existent, hello)
		local TRANSIENT = giop.SystemExceptionIDs.TRANSIENT
		local unavailable = (ok and result)
		                 or (not ok and result._repid == TRANSIENT)
		if unavailable then
			io.write "Server object is not avaliable yet "
			for i=1, dots do io.write "." oil.sleep(secs/dots) end
			print()
		end
	until not unavailable

	hello:_set_quiet(false)
	for i = 1, 3 do print(hello:say_hello_to("world")) end
	print("Object already said hello "..hello:_get_count().." times till now.")
	
	orb:shutdown()
end)
