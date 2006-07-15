require "oil.init_dummy"                                   -- Load OiL package

oil.verbose:level(5)
oil.Config._type = 'dummy'

local hello = { }       -- Get object implementation
function hello:say_hello_to(name)
	local msg = "Hello " .. name .. "!"
	print(msg)
	return msg
end

hello = oil.newobject(hello, "Hello") -- Create object

local file = io.open("hello.ior", "w")
if file then
	file:write(oil.getreference(hello))                      -- Write object ref. into file
	file:close()
else
	print(hello:_getreference())                           -- Show object ref. on screen
end

print(oil.run())                                -- Start ORB main loop
