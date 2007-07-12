require "oil"
oil.main(function()
	------------------------------------------------------------------------------
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
	------------------------------------------------------------------------------
	local server_impl = {}
	function server_impl:do_something_for(seconds)
		print("about to sleep for "..seconds.." seconds")
		oil.sleep(seconds)
		return true
	end
	local adaptor_impl = {}
	function adaptor_impl:update_definition(definition)
		oil.loadidl(definition)
	end
	------------------------------------------------------------------------------
	local server = oil.newsevant(server_impl, "IDL:Adaptation/Server:1.0")
	local adaptor = oil.newsevant(adaptor_impl, "IDL:Adaptation/Adaptor:1.0")
	------------------------------------------------------------------------------
	oil.writeto("server.ior", oil.tostring(server))
	oil.writeto("serveradaptor.ior", oil.tostring(adaptor))
	------------------------------------------------------------------------------
	oil.run()
end)
