require "oil"                                   -- Load OiL package

oil.Config.flavor = "DummySimple"
oil.verbose:level(5)
oil.init()

local hello = { }       -- Get object implementation
function hello:say_hello_to(name)
	local msg = "hello " .. name .. "!"
	print(msg)
	return msg
end
function hello:say_2_strings(str1, str2)
	print(str1, str2)
	return str1.."done", str2.."done"
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
