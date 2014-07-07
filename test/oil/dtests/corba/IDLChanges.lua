local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Lua = {}
function Lua:dostring(chunk)
	assert(load(chunk))()
end

orb = oil.dtests.init{ port = 2809 }
Lua.__type = orb:loadidl("interface Lua { void dostring(in string chunk); };")
orb:newservant(Lua, "object")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
object = oil.dtests.resolve("Server", 2809, "object")

local newiface = "interface Lua { string say_hello(); };"

object:dostring([[
	orb:loadidl("]]..newiface..[[")
	function Lua:say_hello()
		return "Hello, World!"
	end
]])

orb:loadidl(newiface)

assert(object:say_hello() == "Hello, World!")
assert(object.dostring == nil, "old method was not removed from proxy class cache")

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true }
