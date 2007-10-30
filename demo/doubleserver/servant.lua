require "oil"                                   -- Load OiL package

oil.Config.flavor = "CORBAServerDummyServer"
oil.Config.ports = {}
oil.Config.ports.corba = { host = "localhost", port = 2809} 
oil.Config.ports.dummy = { host = "localhost", port = 2810} 
oil.verbose:level(5)
oil.init()

oil.loadidlfile("hello.idl")                    -- Load the interface from IDL file

local hello = { count = 0, quiet = true }       -- Get object implementation
function hello:say_hello_to(name)
	self.count = self.count + 1
	local msg = "Hello " .. name .. "! ("..self.count.." times)"
	if not self.quiet then print(msg) end
	return msg
end

hello = oil.newobject(hello, "Hello")           -- Create CORBA object

for _, type in pairs({ "corba", "dummy" }) do

	local file = assert(io.open("server" .. type ..".ior", "w"))
	if file then
		file:write(oil.getreference(hello, type))                      -- Write object ref. into file
		file:close()
	end
end
print(oil.run())                                -- Start ORB main loop
