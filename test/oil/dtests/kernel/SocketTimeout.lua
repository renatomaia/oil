local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{
	port = 2809,
	tcpoptions = {timeout=.1}
}

if oil.dtests.flavor.cooperative then
	socket = require "cothread.socket"
else
	socket = require "socket.core"
end

obj = {}
function obj:open(port)
	local p = socket.tcp()
	p:bind("*", port)
	p:listen()
end
if oil.dtests.flavor.corba then
	obj.__type = orb:loadidl"interface Ports { void open(in short port); };"
end
orb:newservant(obj, "object")

orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init{ options = { tcp = {timeout=.1} } }
obj = oil.dtests.resolve("Server", 2809, "object")

host = oil.dtests.hosts.Server
obj:open(2808)

if oil.dtests.flavor.corba then
	local idl = require "oil.corba.idl"
	ref, type = "corbaloc::"..host..":2808/FakeObject", "Ports"
else
	ref, type = "return 'FakeObject', '"..host.."', 2808\0"
end

obj = orb:newproxy(ref, nil, type)
ok, ex = pcall(obj.open, obj, 80)
assert(ok == false)
assert(ex.error == "timeout")

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite()
