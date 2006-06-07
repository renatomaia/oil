require "scheduler"
require "oil"

oil.verbose.output(io.open("proxy.log", "w"))
oil.verbose.level(4)
oil.verbose.flag("unmarshall", true)
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
		interface Proxy {
			boolean request_work_for(in long seconds);
		};
		interface Adaptor {
			void update_definition(in string definition);
		};
	};
]]
--------------------------------------------------------------------------------
local proxy_impl = {
	server = oil.newproxy(oil.readIOR("server.ior"), "IDL:Adaptation/Server:1.0")
}
function proxy_impl:request_work_for(seconds)
	assert(self.server, "unable to find a server")
	return self.server:do_something_for(seconds)
end
local adaptor_impl = {}
function adaptor_impl:update_definition(definition)
	oil.loadidl(definition)
end
--------------------------------------------------------------------------------
local proxy = oil.newobject(proxy_impl, "IDL:Adaptation/Proxy:1.0")
local adaptor = oil.newobject(adaptor_impl, "IDL:Adaptation/Adaptor:1.0")
--------------------------------------------------------------------------------
oil.writeIOR(proxy, "proxy.ior")
oil.writeIOR(adaptor, "proxyadaptor.ior")
--------------------------------------------------------------------------------
scheduler.new(oil.run)
scheduler.run()
