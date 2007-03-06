require "oil"
oil.assemble "corba.typed.cooperative.base"
oil.main(function()
	------------------------------------------------------------------------------
	local server = oil.newproxy(assert(oil.readfrom("server.ior")))
	------------------------------------------------------------------------------
	oil.loadidl [[
		module Concurrency {
			interface Proxy {
				boolean request_work_for(in double seconds);
			};
		};
	]]
	------------------------------------------------------------------------------
	local proxy_impl = { server = server }
	function proxy_impl:request_work_for(seconds)
		return server:do_something_for(seconds)
	end
	------------------------------------------------------------------------------
	local proxy = oil.newobject(proxy_impl, "Concurrency::Proxy")
	------------------------------------------------------------------------------
	assert(oil.writeto("proxy.ior", oil.tostring(proxy)))
	------------------------------------------------------------------------------
	oil.run()
	------------------------------------------------------------------------------
end)
