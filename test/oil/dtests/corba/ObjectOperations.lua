local Suite = require "loop.test.Suite"
local Template = require"oil.dtests.Template"
local test = Template{"Client"} -- master process name

Server = [=====================================================================[
oil.init{ port = 2809 }
oil.newservant({}, "::CORBA::InterfaceDef", "object")
oil.run()
--[Server]=====================================================================]

Client = [=====================================================================[
table = require "loop.table"

checks = oil.dtests.checks
object = oil.dtests.resolve("Server", 2809, "object", false, true)
fake   = oil.dtests.resolve("", 0, "", true, true)

cases = {
	_narrow = {
		[object] = { checks.similar(table.copy(object), nil, {isomorphic=false}) },
	},
	_interface = {
		[object] = { checks.similar(oil.types:lookup("::CORBA::InterfaceDef"), nil, {isomorphic=false}) },
	},
	_component = {
		[object] = { checks.is(nil) },
	},
	_is_a = { "IDL:omg.org/CORBA/InterfaceDef:1.0",
		[object] = { checks.is(true) },
	},
	_non_existent = {
		[object] = { checks.is(false) },
		[fake]   = { checks.is(true) },
	},
	_is_equivalent = { object,
		[object] = { checks.is(true) },
		[fake]   = { checks.is(false) },
	},
}

for opname, opdesc in pairs(cases) do
	for proxy, checkers in pairs(opdesc) do
		if proxy ~= 1 then
			-- synchronous call
			result = proxy[opname](proxy, unpack(opdesc))
			checks:assert(result, checker)
			
			-- asynchronous call
			future = proxy.__deferred[opname](proxy.__deferred, unpack(opdesc))
			ok, result = future:results()
			checks:assert(ok, checks.is(true, "operation results indicated a unexpected error."))
			checks:assert(result, checker)
			checks:assert(future:evaluate(), checker)
			
			-- protected synchronous call
			ok, result = proxy.__try[opname](proxy.__try, unpack(opdesc))
			checks:assert(ok, checks.is(true, "operation results indicated a unexpected error."))
			checks:assert(result, checker)
			
		end
	end
end
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
