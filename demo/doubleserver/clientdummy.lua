require "oil"

oil.Config.flavor = "DummySimple"
oil.verbose:level(5)
oil.init()
--------------------------------------------------------------------------------
-- Get object reference from file ----------------------------------------------

local ior
local file = io.open("serverdummy.ior")
if file then
	ior = file:read("*a")
	file:close()
else
	print "unable to read IOR from file 'proxy.ior'"
	os.exit(1)
end

--------------------------------------------------------------------------------
-- Create an object proxy for the supplied interface ---------------------------

local hello = oil.newproxy(ior, "Hello")

--------------------------------------------------------------------------------
-- Access remote dummy object --------------------------------------------------

print(hello:say_hello_to("world")) 
