require "oil.init_dummy"

oil.verbose:level(5)

--------------------------------------------------------------------------------
-- Get object reference from file ----------------------------------------------

local ior
local file = io.open("proxy.ior")
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

for i = 1, 3 do 
	print(hello:say_hello_to("world")) 
	os.execute('sleep 1')
end
