local oil = require "oil"

oil.main(function()
	local orb = oil.init()
	orb:loadidl("interface MyObject { void shutdown(); };")
	local obj = {shutdown = function() orb:shutdown() end}
	local prx = orb:newproxy(tostring(orb:newservant(obj, nil, "MyObject")))
	assert(prx:_is_a("IDL:MyObject:1.0"), "Oops, wrong interface")
	prx:shutdown()
	local success, except = pcall(prx.shutdown, prx)
	assert(not success)
	assert(except._repid == "IDL:omg.org/CORBA/BAD_INV_ORDER:1.0")
end)
