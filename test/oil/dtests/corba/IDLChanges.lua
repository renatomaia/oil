local Suite = require "loop.test.Suite"
local Template = require"oil.dtests.Template"
local test = Template{"Client"} -- master process name

Server = [=====================================================================[
Lua = {}
function Lua:dostring(chunk)
	assert(loadstring(chunk))()
end

oil.init{ port = 2809 }
oil.loadidl("interface Lua { void dostring(in string chunk); };")
oil.newservant(Lua, "::Lua", "object")
oil.run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks
object = oil.dtests.resolve("Server", 2809, "object")

local newiface = "interface Lua { void say_hello(); };"

object:dostring([[
	oil.loadidl("]]..newiface..[[")
	function Lua:say_hello()
		print "Hello, World!"
	end
]])

oil.loadidl(newiface)
object:say_hello()
checks:assert(object.dostring == nil, "old method was not removed from proxy class cache")
--[Client]=====================================================================]

return Suite{
	CoCORBA = test{
		Server = { flavor = "corba;typed;cooperative;base" },
		Client = { flavor = "corba;typed;cooperative;base" },
	},
	CoServerCORBA = test{
		Server = { flavor = "corba;typed;cooperative;base" },
		Client = { flavor = "corba;typed;base" },
	},
	CoClientCORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "corba;typed;cooperative;base" },
	},
	CORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "corba;typed;base" },
	},
	
	IceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoServerIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoClientIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	CoIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	
	IceptedClientCORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoServerIceptedClientCORBA = test{
		Server = { flavor = "corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoIceptedClientCORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	IceptedClientCoCORBA = test{
		Server = { flavor = "corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	
	IceptedServerCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "corba;typed;base" },
	},
	CoIceptedServerCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "corba;typed;base" },
	},
	IceptedServerCoClientCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "corba;typed;cooperative;base" },
	},
	IceptedServerCoCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "corba;typed;cooperative;base" },
	},
}
