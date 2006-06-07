require "oil"

oil.loadidlfile("../hello/hello.idl")

local hello = { count = 0, quiet = true }
function hello:say_hello_to(name)
	self.count = self.count + 1
	local msg = "Hello " .. name .. "! ("..self.count.." times)"
	if not self.quiet then print(msg) end
	return msg
end

oil.init{ port = 2809 }
hello = oil.newobject(hello, "IDL:Hello:1.0", "MyHello")

print(oil.run())
