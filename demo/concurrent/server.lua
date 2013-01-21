oil = require "oil"
oil.main(function()
	orb = oil.init()
	orb:loadidl [[
		module Concurrency {
			interface Server {
				boolean do_something_for(in double seconds);
			};
		};
	]]
	server_impl = {}
	function server_impl:do_something_for(seconds)
		oil.sleep(seconds)
		return true
	end
	server = orb:newservant(server_impl, nil, "Concurrency::Server")
	assert(oil.writeto("server.ior", tostring(server)))
	orb:run()
end)
