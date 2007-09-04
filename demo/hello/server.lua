require "oil"                                    -- Load OiL package

oil.loadidl [[                                   // Load the interface IDL
	interface Hello {
		attribute boolean quiet;
		readonly attribute long count;
		string say_hello_to(in string name);
	};
]]

oil.main(function()
	local hello = { count = 0, quiet = true }      -- Get object implementation
	function hello:say_hello_to(name)
		self.count = self.count + 1
		local msg = "Hello " .. name .. "! ("..self.count.." times)"
		if not self.quiet then print(msg) end
		return msg
	end

	hello = oil.newservant(hello, "Hello")         -- Create CORBA object

	local ref = oil.tostring(hello)                -- Get object's reference
	if not oil.writeto("ref.ior", ref) then
		print(ref)
	end

	oil.run()                                      -- Start ORB main loop
end)
