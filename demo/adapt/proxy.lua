require "Adaptor"
require "oil"
oil.main(function()
	local orb = oil.init()
	------------------------------------------------------------------------------
	orb:loadidl [[
		module Concurrent {
			interface Proxy {
				long request_work_for(in long seconds);
			};
		};
	]]
	------------------------------------------------------------------------------
	local proxy_impl = {
		__type = "Concurrent::Proxy",
		server = orb:newproxy(oil.readfrom("server.ior"))
	}
	function proxy_impl:request_work_for(seconds)
		assert(self.server, "unable to find a server")
		return self.server:do_something_for(seconds)
	end
	local proxy = orb:newservant(proxy_impl)
	------------------------------------------------------------------------------
	local adaptor = Adaptor{
		orb = orb,
		object = proxy_impl,
		servant = proxy,
	}
	------------------------------------------------------------------------------
	oil.writeto("proxy.ior", tostring(proxy))
	oil.writeto("proxyadaptor.ior", tostring(adaptor))
	------------------------------------------------------------------------------
	orb:run()
	------------------------------------------------------------------------------
end)
