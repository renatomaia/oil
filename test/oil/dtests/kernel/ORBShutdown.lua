local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	iface = orb:loadidl "interface Terminator { void shutdown(); void idle(); };"
end
orb:newservant{
	__objkey = "object",
	__type = iface,
	idle = function() oil.sleep(1) end,
	shutdown = function() orb:shutdown() end,
}
orb:run()
--[Server]=====================================================================]

Caller = [=====================================================================[
orb = oil.dtests.init()
obj = oil.dtests.resolve("Server", 2809, "object")
obj:idle()
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
	checks:assert(obj:_non_existent(), checks.is(true))
else
	ok, ex = pcall(obj.idle, obj)
	checks:assert(ok, checks.is(false))
	checks:assert(ex, checks.similar{
		errmsg = "connection refused",
		error = "badconnect",
	})
end
--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
