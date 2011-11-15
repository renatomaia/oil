local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Caller = {}
function Caller:call(obj)
	obj:ack()
end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	orb:loadidl[[
		interface Callback { void ack(); };
		interface Caller { void call(in Callback obj); };
	]]
	Caller.__type = "Caller"
end
orb:newservant(Caller, "object")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init()
oil.newthread(orb.run, orb)

Caller = oil.dtests.resolve("Server", 2809, "object")
Caller:call({ ack = function() end })

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ cooperative = true, corba = true }
