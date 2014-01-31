return function()
	local oil = require "oil"
	local orb = oil.init()
	for _, typename in ipairs{
		"valuetype",
		"interface",
		"abstract interface",
		"local interface",
	} do
		orb:loadidl([[
			]]..typename..[[ A { };
			typedef A B;
			]]..typename..[[ C : B { };
		]])
		local inherited = orb.types:lookup("C")
		assert(inherited:is_a("IDL:A:1.0"))
	end
	orb:shutdown()
end
