local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local T = Template{"Client"} -- master process name

T.Server = [===================================================================[
Lua = {}
function Lua:dostring(chunk)
	assert(loadstring(chunk))()
end

orb = oil.dtests.init{ port = 2809 }
Lua.__type = orb:loadidl("interface Lua { void dostring(in string chunk); };")
orb:newservant(Lua, "object")
orb:run()
----[Server]===================================================================]

T.Client = [===================================================================[
orb = oil.dtests.init()
checks = oil.dtests.checks
object = oil.dtests.resolve("Server", 2809, "object")

local newiface = "interface Lua { string say_hello(); };"

object:dostring([[
	orb:loadidl("]]..newiface..[[")
	function Lua:say_hello()
		return "Hello, World!"
	end
]])

orb:loadidl(newiface)

checks:assert(object:say_hello(), checks.is("Hello, World!"))
checks:assert(object.dostring, checks.is(nil, "old method was not removed from proxy class cache"))
----[Client]===================================================================]

return T:newsuite{ corba = true }
