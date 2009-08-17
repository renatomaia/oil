LuaServer = {}
function LuaServer:dostring(chunk)
	assert(loadstring(chunk))()
end

local oil = require "oil"

oil.loadidl[[
	interface Server {
		void dostring(in string chunk);
	};
]]

oil.main(function()
	oil.init{ port = 2809 }
	oil.newservant(LuaServer, "Server", "LuaServer")
	oil.run()
end)
