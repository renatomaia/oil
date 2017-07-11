local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	iface = orb:loadidl[[
		interface Terminator {
			void startup();
			void shutdown();
		};
	]]
end
orb:newservant{
	__objkey = "object",
	__type = iface,
	startup = function() done = true end,
	shutdown = function() orb:shutdown() end,
}
repeat orb:step() until done
--[Server]=====================================================================]

Caller = [=====================================================================[
orb = oil.dtests.init()
obj = oil.dtests.resolve("Server", 2809, "object")
obj:startup()
--[Caller]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

oil.sleep(3)
orb = oil.dtests.init()
obj = oil.dtests.resolve("Server", 2809, "object")

obj:shutdown()
oil.sleep(1)

if oil.dtests.flavor.corba then
	corba = orb
else
	corba = oil.init()
end
server = corba:newproxy(os.getenv("DTEST_HELPER")):getprocess("Server")
assert(server == nil)

if oil.dtests.flavor.corba then
	ok, ex = pcall(obj._non_existent, obj)
	assert(ok == false)
	if ex.error == "timeout" then
		checks.assert(ex, checks.like{
			_repid = "IDL:omg.org/CORBA/TIMEOUT:1.0",
			completed = "COMPLETED_NO",
			errmsg = "timeout",
		})
	else
		checks.assert(ex, checks.like{
			_repid = "IDL:omg.org/CORBA/TRANSIENT:1.0",
			completed = "COMPLETED_NO",
			minor = 2,
			error = "badconnect",
			errmsg = "connection refused",
		})
	end
else
	corba:shutdown()
	ok, ex = pcall(obj.idle, obj)
	assert(ok == false)
	if ex.error == "timeout" then
		checks.assert(ex, checks.like{
			errmsg = "timeout",
		})
	else
		checks.assert(ex, checks.like{
			errmsg = "connection refused",
			error = "badconnect",
		})
	end
end

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
