require "scheduler"
require "oil"

oil.verbose.output(io.open("proxy.log", "w"))
oil.verbose.level(4)
oil.verbose.flag("threads", true)

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
local ior
local file = io.open("server.ior")
if file then
	ior = file:read("*a")
	file:close()
else
	print "unable to read IOR from file 'server.ior'"
	os.exit(1)
end
--------------------------------------------------------------------------------
local proxy_impl = { server = oil.newproxy(ior, "Concurrency::Server") }
function proxy_impl:request_work_for(seconds)
	assert(self.server, "unable to find a server")
	return self.server:do_something_for(seconds)
end
--------------------------------------------------------------------------------
local proxy = oil.newobject(proxy_impl, "Concurrency::Proxy")
--------------------------------------------------------------------------------
oil.writeIOR(proxy, "proxy.ior")
--------------------------------------------------------------------------------
scheduler.new(oil.run)
scheduler.run()
