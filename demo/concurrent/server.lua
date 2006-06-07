require "scheduler"
require "oil"

oil.verbose.output(io.open("server.log", "w"))
oil.verbose.level(4)
oil.verbose.flag("threads", true)

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
	scheduler.sleep(seconds)
	return true
end
--------------------------------------------------------------------------------
local server = oil.newobject(server_impl, "Concurrency::Server")
--------------------------------------------------------------------------------
oil.writeIOR(server, "server.ior")
--------------------------------------------------------------------------------
scheduler.new(oil.run)
scheduler.run()
