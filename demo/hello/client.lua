require "oil"

oil.verbose:level(5)

--------------------------------------------------------------------------------
-- Load the interface from IDL file --------------------------------------------

oil.loadidlfile("hello.idl")

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

print( "****", hello:_is_a("IDL:Hello:1.0") )
--------------------------------------------------------------------------------
-- Access remote CORBA object --------------------------------------------------

hello.quiet = false
for i = 1, 3 do 
	print(hello:say_hello_to("world")) 
	os.execute('sleep 1')
end
print("Object already said hello "..hello.count.." times till now.")
