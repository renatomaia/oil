require "oil"

oil.Config.flavor = "CORBASimple"
oil.verbose:level(5)
oil.init()

--------------------------------------------------------------------------------
-- Load the interface from IDL file --------------------------------------------

oil.loadidlfile("hello.idl")

--------------------------------------------------------------------------------
-- Get object reference from file ----------------------------------------------

local ior
local file = io.open("servercorba.ior")
if file then
	ior = file:read("*a")
	file:close()
else
	print "unable to read IOR from file 'hello.ior'"
	os.exit(1)
end
--------------------------------------------------------------------------------
-- Create an object proxy for the supplied interface ---------------------------

local hello_prx = oil.newproxy(ior, "Hello")

print(hello_prx:say_hello_to("world")) 

