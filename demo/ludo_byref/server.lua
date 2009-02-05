oil = {BasicSystem = false} -- disable multithreading support

require "oil"

oil.main(function()
	local hello = { count = 0, quiet = true }
	function hello:say_hello_to(name)
		self.count = self.count + 1
		local msg = "Hello " .. name .. "! ("..self.count.." times)"
		if not self.quiet then print(msg) end
		return msg
	end
	function hello:_get_count()
		return self.count
	end
	function hello:_set_quiet(value)
		self.quiet = value
	end

	local orb = oil.init{ flavor = "lua;ludo;ludo.byref" }
	
	hello = orb:newservant(hello)

	local ref = tostring(hello)
	if not oil.writeto("ref.ludo", ref) then
		print(ref)
	end

	orb:run()
end)
