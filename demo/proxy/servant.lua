require "oil"                                   -- Load OiL package

oil.verbose:level(5)

oil.loadidlfile("hello.idl")                    -- Load the interface from IDL file

local hello = { count = 0, quiet = true }       -- Get object implementation
function hello:say_hello_to(name)
	self.count = self.count + 1
	local msg = "Hello " .. name .. "! ("..self.count.." times)"
	if not self.quiet then print(msg) end
	return msg
end

hello = oil.newobject(hello, "Hello")           -- Create CORBA object

local file = io.open("server.ior", "w")
if file then
	file:write(oil.getreference(hello))                      -- Write object ref. into file
	file:close()
else
	print(oil.getreference(hello))                           -- Show object ref. on screen
end

print(oil.run())                                -- Start ORB main loop
