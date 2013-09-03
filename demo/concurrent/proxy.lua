oil = require "oil"
oil.main(function()
	orb = oil.init()
	server = orb:newproxy(assert(oil.readfrom("server.ior")))
	orb:loadidl [[
		module Concurrency {
			interface Proxy {
				boolean request_work_for(in double seconds);
			};
		};
	]]
	proxy_impl = { server = server }
	function proxy_impl:request_work_for(seconds)
		return server:do_something_for(seconds)
	end
	proxy = orb:newservant(proxy_impl, nil, "Concurrency::Proxy")
	assert(oil.writeto("proxy.ior", tostring(proxy)))
	orb:run()
end)
