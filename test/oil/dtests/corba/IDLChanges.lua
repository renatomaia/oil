local Suite = require "loop.test.Suite"
local Template = require"oil.dtests.Template"
local template = Template{"Client"} -- master process name

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

return template:newsuite{ corba = true }
