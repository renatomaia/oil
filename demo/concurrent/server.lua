require "oil"
oil.assemble "corba.typed.cooperative.base"
oil.main(function()
	------------------------------------------------------------------------------
	oil.loadidl [[
		module Concurrency {
			interface Server {
				boolean do_something_for(in double seconds);
			};
		};
	]]
	------------------------------------------------------------------------------
	local server_impl = {}
	function server_impl:do_something_for(seconds)
		oil.sleep(seconds)
		return true
	end
	------------------------------------------------------------------------------
	local server = oil.newobject(server_impl, "Concurrency::Server")
	------------------------------------------------------------------------------
	assert(oil.writeto("server.ior", oil.tostring(server)))
	------------------------------------------------------------------------------
	oil.run()
	------------------------------------------------------------------------------
end)
