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
checks:assert(server, checks.is(nil))

if oil.dtests.flavor.corba then
	ok, ex = pcall(obj._non_existent, obj)
	checks:assert(ok, checks.is(false))
	checks:assert(ex, checks.similar{
		_repid = "IDL:omg.org/CORBA/TRANSIENT:1.0",
		completed = "COMPLETED_NO",
		minor = 2,
		error = "badconnect",
		errmsg = "connection refused",
	})
else
	ok, ex = pcall(obj.idle, obj)
	checks:assert(ok, checks.is(false))
	checks:assert(ex, checks.similar{
		errmsg = "connection refused",
		error = "badconnect",
	})
end

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
