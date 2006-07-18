require "oil"

oil.verbose:level(5)
loop.thread.Scheduler.verbose:flag("threads", true)

--------------------------------------------------------------------------------
oil.loadidl [[
	module Concurrency {
		interface Server {
			boolean do_something_for(in double seconds);
		};
	};
]]
--------------------------------------------------------------------------------
local server_impl = {}
function server_impl:do_something_for(seconds)
	oil.myScheduler.threads:suspend(seconds)
	return true
end
--------------------------------------------------------------------------------
local server = oil.newobject(server_impl, "Concurrency::Server")
--------------------------------------------------------------------------------

oil.writeIOR(server, "server.ior")
--------------------------------------------------------------------------------
oil.run()