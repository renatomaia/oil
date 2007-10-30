require "oil"

oil.Config.flavor = "CORBAClientDummyServer"
oil.Config.port = 2810
oil.verbose:level(5)
oil.init()

--------------------------------------------------------------------------------
-- Load the interface from IDL file --------------------------------------------

oil.loadidlfile("hello.idl")

--------------------------------------------------------------------------------
-- Get object reference from file ----------------------------------------------

local ior
local file = io.open("server.ior")
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

local hello_srv = {}       -- Get object implementation
function hello_srv:say_hello_to(name)
	return hello_prx:say_hello_to(name)
end

hello_obj = oil.newservant(hello_srv, "Hello") -- Create object

local file = io.open("proxy.ior", "w")
if file then
	file:write(oil.getreference(hello_obj))                      -- Write object ref. into file
	file:close()
else
	print(oil.getreference(hello_obj))                           -- Show object ref. on screen
end

print(oil.run())                                -- Start ORB main loop

