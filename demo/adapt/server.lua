require "scheduler"
require "oil"

oil.verbose.output(io.open("server.log", "w"))
oil.verbose.level(4)
oil.verbose.flag("ir", true)
oil.verbose.flag("threads", true)

--------------------------------------------------------------------------------
oil.init{ manager = oil.manager.new() } -- IR object manager does not suport
                                        -- adaptation yet.
--------------------------------------------------------------------------------
oil.loadidl [[
	module Adaptation {
		interface Server {
			boolean do_something_for(in long seconds);
		};
		interface Adaptor {
			void update_definition(in string definition);
		};
	};
]]
--------------------------------------------------------------------------------
local server_impl = {}
function server_impl:do_something_for(seconds)
	print("about to sleep for "..seconds.." seconds")
	scheduler.sleep(seconds)
	return true
end
local adaptor_impl = {}
function adaptor_impl:update_definition(definition)
	oil.loadidl(definition)
end
--------------------------------------------------------------------------------
local server = oil.newobject(server_impl, "IDL:Adaptation/Server:1.0")
local adaptor = oil.newobject(adaptor_impl, "IDL:Adaptation/Adaptor:1.0")
--------------------------------------------------------------------------------
oil.writeIOR(server, "server.ior")
oil.writeIOR(adaptor, "serveradaptor.ior")
--------------------------------------------------------------------------------
scheduler.new(oil.run)
scheduler.run()
