oil = require "oil"                                     -- Load OiL package

oil.main(function()
	orb = oil.init{
		flavor = "cooperative;corba;corba.ssl",
		options = {
			client = {
				security = "preferred",
				ssl = {
					key = "../../certs/clientAkey.pem",
					certificate = "../../certs/clientA.pem",
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
	
	hello = orb:newproxy(assert(oil.readfrom("ref.ior")), nil, "Hello") -- Get proxy to object

	hello:_set_quiet(false)                               -- Access the object
	for i = 1, 3 do print(hello:say_hello_to("world")) end
	print("Object already said hello "..hello:_get_count().." times till now.")
	
	orb:shutdown()
end)
