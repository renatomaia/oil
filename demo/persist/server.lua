require "oil"
oil.main(function()
	local orb = oil.init{ port = 2809 }
	
	orb:loadidlfile("hello.idl")
	

local MIN, MAX = math.huge, 0

	local hello = { count = 0, quiet = true }
	function hello:say_hello_to(name)
		self.count = self.count + 1
		local msg = "Hello " .. name .. "! ("..self.count.." times)"
		if not self.quiet then print(msg) end

local count = collectgarbage("count")
MIN = math.min(count, MIN)
MAX = math.max(count, MAX)
print(count, MIN, MAX)

		return msg
	end
	
	hello = orb:newservant(hello, "MyHello", "Hello")
	
	orb:run()
end)
