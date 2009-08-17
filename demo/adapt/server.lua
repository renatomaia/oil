require "Adaptor"
require "oil"
oil.main(function()
	local orb = oil.init()
	------------------------------------------------------------------------------
	orb:loadidl [[
		module Concurrent {
			interface Server {
				long do_something_for(in long seconds);
			};
		};
	]]
	------------------------------------------------------------------------------
	local server_impl = { __type = "Concurrent::Server" }
	function server_impl:do_something_for(seconds)
		print("about to sleep for "..seconds.." seconds")
		oil.sleep(seconds)
		return seconds
	end
	local server = orb:newservant(server_impl)
	------------------------------------------------------------------------------
	local adaptor = Adaptor{
		orb = orb,
		object = server_impl,
		servant = server,
	}
	------------------------------------------------------------------------------
	oil.writeto("server.ior", tostring(server))
	oil.writeto("serveradaptor.ior", tostring(adaptor))
	------------------------------------------------------------------------------
	orb:run()
end)
