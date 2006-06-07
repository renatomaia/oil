local oo = require "loop.simple"

--------------------------------------------------------------------------------
-- Observer Component
--------------------------------------------------------------------------------

Observer = oo.class()

function Observer:push(info)
	io.write(info.name)
	io.write(string.rep(" ", 20 - string.len(info.name)))
	io.write(info.state, "\t")
	if info.has_left_fork
		then io.write(" * ")
		else io.write("   ")
	end
	if info.has_right_fork
		then io.write(" * ")
		else io.write("   ")
	end
	for i=1, info.ticks_since_last_meal do
		io.write(".")
	end
	io.write("\n")
end

--------------------------------------------------------------------------------
-- Observer Component
--------------------------------------------------------------------------------

require "adaptor"

ObserverHome = oo.class(nil, Adaptor)

function ObserverHome:create()
	return Observer()
end

--------------------------------------------------------------------------------
-- Exporting
--------------------------------------------------------------------------------

local scheduler = require "scheduler"
local oil       = require "oil"

oil.loadidlfile("philo.idl")
oil.writeIOR(oil.newobject(ObserverHome, "ObserverHome"), "observer.ior")
scheduler.new(oil.run)
scheduler.run()
