require "oil"
oil.main(function()
	------------------------------------------------------------------------------
	oil.loadidl [[
		module Adaptation {
			interface Server {
				boolean do_something_for(in long seconds);
			};
			interface Proxy {
				boolean request_work_for(in long seconds);
			};
			interface Adaptor {
				void update_definition(in string definition);
			};
		};
	]]
	------------------------------------------------------------------------------
	local proxy_impl = {
		server = oil.newproxy(oil.readfrom("server.ior"), "IDL:Adaptation/Server:1.0")
	}
	function proxy_impl:request_work_for(seconds)
		assert(self.server, "unable to find a server")
		return self.server:do_something_for(seconds)
	end
	local adaptor_impl = {}
	function adaptor_impl:update_definition(definition)
		oil.loadidl(definition)
	end
	------------------------------------------------------------------------------
	local proxy = oil.newsevant(proxy_impl, "IDL:Adaptation/Proxy:1.0")
	local adaptor = oil.newsevant(adaptor_impl, "IDL:Adaptation/Adaptor:1.0")
	------------------------------------------------------------------------------
	oil.writeto("proxy.ior", oil.tostring(proxy))
	oil.writeto("proxyadaptor.ior", oil.tostring(adaptor))
	------------------------------------------------------------------------------
	oil.run()
	------------------------------------------------------------------------------
end)
