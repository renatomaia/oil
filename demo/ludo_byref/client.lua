oil = {BasicSystem = false} -- disable multithreading support

require "oil"

oil.main(function()
	local orb = oil.init{ flavor = "lua;ludo;ludo.byref" }
	
	local hello = orb:newproxy(assert(oil.readfrom("ref.ludo")))
	
	hello.quiet = false
	for i = 1, 3 do print(hello:say_hello_to("world")) end
	print("Object already said hello "..hello.count.." times till now.")
	
	--[[ the following only works with multithreading in LuaJIT + Coco
	oil.newthread(orb.run, orb)
	
	local clone = setmetatable({ count = 10 }, { __index = hello })
	for i = 1, 3 do print(clone:say_hello_to("world")) end
	print("Clone already said hello "..clone.count.." times till now.")
	
	print("Object already said hello "..hello.count.." times till now.")
	
	orb:shutdown()
	--]]
end)
