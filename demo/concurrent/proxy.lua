require "oil"

oil.verbose:level(5)
loop.thread.Scheduler.verbose:flag("threads", true)

--------------------------------------------------------------------------------
oil.loadidl [[
	module Concurrency {
		interface Server {
			boolean do_something_for(in double seconds);
		};
		interface Proxy {
			boolean request_work_for(in double seconds);
		};
	};
]]
--------------------------------------------------------------------------------
local ior = oil.readIOR("server.ior")
--------------------------------------------------------------------------------
local proxy_impl = { server = oil.newproxy(ior, "Concurrency::Server") }
function proxy_impl:request_work_for(seconds)
	assert(self.server, "unable to find a server")
	return self.server:do_something_for(seconds)
end
--------------------------------------------------------------------------------
local proxy = oil.newobject(proxy_impl, "Concurrency::Proxy", nil, {host="localhost", port=2810})
--------------------------------------------------------------------------------
oil.writeIOR(proxy, "proxy.ior")
--------------------------------------------------------------------------------
oil.run()
