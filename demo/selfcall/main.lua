require "scheduler"
require "oil"

oil.verbose.level(4)

oil.loadidl[[ interface Hello {}; ]]

scheduler.new(function()
	local obj = oil.newobject({hello=print}, "IDL:Hello:1.0")
	local prx = oil.newproxy(obj:_ior())
	print(prx:_is_a("IDL:Hello:1.0"))
end)

scheduler.new(oil.run)

scheduler.run()