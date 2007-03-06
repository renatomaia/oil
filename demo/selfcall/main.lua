require "oil"

oil.assemble "corba.typed.cooperative.base"

oil.loadidl("interface MyObject { void shutdown(); };")

oil.main(function()
	oil.newthread(oil.run)
	local obj = oil.newobject({shutdown = oil.shutdown}, "MyObject")
	local prx = oil.newproxy(oil.tostring(obj))
	assert(prx:_is_a("IDL:MyObject:1.0"), "Oops, wrong interface")
	prx:shutdown()
	print("OK")
end)
