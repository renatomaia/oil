oil = require "oil"                              -- Load OiL package

oil.main(function()
	hello = { count = 0, quiet = true }            -- Get object implementation
	function hello:say_hello_to(name)
		self.count = self.count + 1
		local msg = "Hello " .. name .. "! ("..self.count.." times)"
		if not self.quiet then print(msg) end
		return msg
	end
	
	orb = oil.init{
		flavor = "cooperative;corba;corba.ssl",
		options = {
			server = {
				security = "required",
				ssl = {
					key = "../../certs/serverAkey.pem",
					certificate = "../../certs/serverA.pem",
					cafile = "../../certs/rootA.pem",
				},
			},
		},
	}
	
	orb:loadidl [[                                 // Load the interface IDL
		interface Hello {
			attribute boolean quiet;
			readonly attribute long count;
			string say_hello_to(in string name);
		};
	]]
	
	hello = orb:newservant(hello, nil, "Hello")    -- Create CORBA object
	
	ref = tostring(hello)                          -- Get object's reference
	if not oil.writeto("ref.ior", ref) then
		print(ref)
	end
end)
