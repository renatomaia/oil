local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{ port = 2809 }

if oil.dtests.flavor.corba then
	type = orb:loadidl[[
		interface Flag {
			void set();
			boolean get();
		};
	]]
end

oo = require "oil.oo"
Flag = oo.class()
function Flag:set()
	self.flag = true
end
function Flag:get()
	return self.flag == true
end

orb:newservant(Flag(), "Unresponsive", type)
orb:newservant(Flag(), "NoConnect", type)

orb:run()
--[Server]=====================================================================]

Unresponsive = [===============================================================[
if oil.dtests.flavor.cooperative then
	socket = require "cothread.socket"
else
	socket = require "socket.core"
end
local p = assert(socket.tcp())
assert(p:bind("*", 2808))
assert(p:listen())

oil.dtests.init()
oil.dtests.resolve("Server", 2809, "Unresponsive"):set()

while true do
	assert(p:accept())
end
--[Unresponsive]===============================================================]

NoConnect = [==================================================================[
if oil.dtests.flavor.cooperative then
	socket = require "cothread.socket"
else
	socket = require "socket.core"
end
local p = assert(socket.tcp())
assert(p:bind("*", 2807))
assert(p:listen())

orb = oil.dtests.init()
oil.dtests.resolve("Server", 2809, "NoConnect"):set()
orb:run()
--[NoConnect]==================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init()

function wait(name)
	local flag = oil.dtests.resolve("Server", 2809, name)
	for i = 1, oil.dtests.timeout/oil.dtests.querytime do
		if flag:get() then return end
		oil.sleep(oil.dtests.querytime)
	end
	error(name.." was not set")
end

wait("Unresponsive")
wait("NoConnect")

if oil.dtests.flavor.corba then
	type = "Flag"
	ref = "corbaloc::%s:%d/FakeObject"
else
	ref = "return 'FakeObject', '%s', %d\0"
end

proxies = {
	unresponsive = orb:newproxy(ref:format(oil.dtests.hosts.Unresponsive, 2808), nil, type),
	noconnect = orb:newproxy(ref:format(oil.dtests.hosts.NoConnect, 2807), nil, type),
	--unreachable = orb:newproxy(ref:format("unreachable", 2806), nil, type),
}

for name, proxy in pairs(proxies) do
	sync = proxy
	prot = orb:newproxy(sync, "protected")
	async = orb:newproxy(sync, "asynchronous")
	for case = 1, 3 do
		if case == 1 then
			sync:__settimeout(.1)
			prot:__settimeout(.1)
		elseif case == 2 then
			orb:settimeout(.1, type)
		elseif case == 3 then
			orb:settimeout(.1)
		end
		
		-- synchronous call
		ok, ex = pcall(sync.get, sync)
		assert(ok == false)
		assert(ex.error == "timeout")
		-- protected call
		ok, ex = prot:get()
		assert(ok == false)
		assert(ex.error == "timeout")
		
		if case == 1 then
			sync:__settimeout(nil)
			prot:__settimeout(nil)
		elseif case == 2 then
			orb:settimeout(nil, type)
		elseif case == 3 then
			orb:settimeout(nil)
		end
	end

	-- asynchronous call
	future = async:get()
	oil.sleep(.1); assert(not future:ready())
	ok, ex = future:results(.1)
	assert(not ok)
	assert(ex.error == "timeout")
	ok, ex = pcall(future.evaluate, future, .1)
	assert(not ok)
	assert(ex.error == "timeout")
end

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite()
