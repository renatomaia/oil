require "oil.init_dummy"                           

oil.verbose:level(5)

--------------------------------------------------------------------------------
-- Get object reference from file ----------------------------------------------

local ior
local file = io.open("hello.ior")
if file then
	ior = file:read("*a")
	file:close()
else
	print "unable to read IOR from file 'hello.ior'"
	os.exit(1)
end

--------------------------------------------------------------------------------
-- Create an object proxy for the supplied interface ---------------------------

local hello = oil.newproxy(ior, "Hello")

--------------------------------------------------------------------------------
-- Access remote object --------------------------------------------------

print(hello:say_hello_to("world"))
