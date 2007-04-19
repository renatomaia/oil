require "oil"                           

oil.Config.flavor = "DummySimple"
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

for i=1,3 do
	print(hello:say_hello_to("world ".. i))
end

print(hello:say_2_strings("test1", "test2"))